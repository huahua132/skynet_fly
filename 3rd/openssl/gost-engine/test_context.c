/*
 * Copyright (C) 2018,2020 Vitaly Chikunov <vt@altlinux.org> All Rights Reserved.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
#include <openssl/engine.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#include <string.h>
#ifndef EVP_MD_CTRL_SET_KEY
# include "gost_lcl.h"
#endif

#define T(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        OpenSSLDie(__FILE__, __LINE__, #e); \
    }

#define cRED	"\033[1;31m"
#define cDRED	"\033[0;31m"
#define cGREEN	"\033[1;32m"
#define cDGREEN	"\033[0;32m"
#define cBLUE	"\033[1;34m"
#define cDBLUE	"\033[0;34m"
#define cNORM	"\033[m"
#define TEST_ASSERT(e) {if ((test = (e))) \
		 printf(cRED "  Test FAILED" cNORM "\n"); \
	     else \
		 printf(cGREEN "  Test passed" cNORM "\n");}

static void hexdump(const void *ptr, size_t len)
{
    const unsigned char *p = ptr;
    size_t i, j;

    for (i = 0; i < len; i += j) {
	for (j = 0; j < 16 && i + j < len; j++)
	    printf("%s%02x", j? "" : " ", p[i + j]);
    }
    printf("\n");
}

#define TEST_SIZE 256
#define STEP_SIZE 16

static int test_contexts_cipher(const char *name, const int enc, int acpkm)
{
    EVP_CIPHER_CTX *ctx, *save;
    unsigned char pt[TEST_SIZE] = {1};
    unsigned char b[TEST_SIZE]; /* base output */
    unsigned char c[TEST_SIZE]; /* cloned output */
    unsigned char K[32] = {1};
    unsigned char iv[16] = {1};
    int outlen, tmplen;
    int ret = 0, test = 0;

    EVP_CIPHER *type;
    ERR_set_mark();
    T((type = (EVP_CIPHER *)EVP_get_cipherbyname(name))
      || (type = EVP_CIPHER_fetch(NULL, name, NULL)));
    ERR_pop_to_mark();

    printf(cBLUE "%s test for %s" cNORM "\n",
           enc ? "Encryption" : "Decryption", name);

    /* produce base encryption */
    ctx = EVP_CIPHER_CTX_new();
    T(ctx);
    T(EVP_CipherInit_ex(ctx, type, NULL, K, iv, enc));
    if (acpkm) {
	if (EVP_CIPHER_get0_provider(type) != NULL) {
	    OSSL_PARAM params[] = { OSSL_PARAM_END, OSSL_PARAM_END };
	    size_t v = (size_t)acpkm;

	    params[0] = OSSL_PARAM_construct_size_t("key-mesh", &v);
	    T(EVP_CIPHER_CTX_set_params(ctx, params));
	} else {
	    T(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_KEY_MESH, acpkm, NULL));
	}
    }
    T(EVP_CIPHER_CTX_set_padding(ctx, 0));
    T(EVP_CipherUpdate(ctx, b, &outlen, pt, sizeof(b)));
    T(EVP_CipherFinal_ex(ctx, b + outlen, &tmplen));

    /* and now tests */
    EVP_CIPHER_CTX_reset(ctx);
    EVP_CIPHER_CTX_reset(ctx); /* double call is intentional */
    T(EVP_CipherInit_ex(ctx, type, NULL, K, iv, enc));
    T(EVP_CIPHER_CTX_set_padding(ctx, 0));
    if (acpkm) {
	if (EVP_CIPHER_get0_provider(type) != NULL) {
	    OSSL_PARAM params[] = { OSSL_PARAM_END, OSSL_PARAM_END };
	    size_t v = (size_t)acpkm;

	    params[0] = OSSL_PARAM_construct_size_t("key-mesh", &v);
	    T(EVP_CIPHER_CTX_set_params(ctx, params));
	} else {
	    T(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_KEY_MESH, acpkm, NULL));
	}
    }
    save = ctx;

    printf(" cloned contexts: ");
    int i;
    memset(c, 0, sizeof(c));
    for (i = 0; i < TEST_SIZE / STEP_SIZE; i++) {
	EVP_CIPHER_CTX *copy = EVP_CIPHER_CTX_new();
	T(copy);
	T(EVP_CIPHER_CTX_copy(copy, ctx));
	if (save != ctx) /* else original context */
	    EVP_CIPHER_CTX_free(ctx);
	ctx = copy;

	T(EVP_CipherUpdate(ctx, c + STEP_SIZE * i, &outlen,
			   pt + STEP_SIZE * i, STEP_SIZE));
    }

    outlen = i * STEP_SIZE;
    T(EVP_CipherFinal_ex(ctx, c + outlen, &tmplen));
    TEST_ASSERT(outlen != TEST_SIZE || memcmp(c, b, TEST_SIZE));
    EVP_CIPHER_CTX_free(ctx);
    if (test) {
	printf("  b[%d] = ", outlen);
	hexdump(b, outlen);
	printf("  c[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    /* resume original context */
    printf("    base context: ");
    memset(c, 0, sizeof(c));
    T(EVP_CipherUpdate(save, c, &outlen, pt, sizeof(c)));
    T(EVP_CipherFinal_ex(save, c + outlen, &tmplen));
    TEST_ASSERT(outlen != TEST_SIZE || memcmp(c, b, TEST_SIZE));
    EVP_CIPHER_CTX_cleanup(save); /* multiple calls are intentional */
    EVP_CIPHER_CTX_cleanup(save);
    EVP_CIPHER_CTX_free(save);
    EVP_CIPHER_free(type);
    if (test) {
	printf("  b[%d] = ", outlen);
	hexdump(b, outlen);
	printf("  c[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    return ret;
}

static int test_contexts_digest_or_legacy_mac(const EVP_MD *type, int mac)
{
    int ret = 0, test = 0;
    unsigned char K[32] = {1};

    /* produce base digest */
    EVP_MD_CTX *ctx, *save;
    unsigned char pt[TEST_SIZE] = {1};
    unsigned char b[EVP_MAX_MD_SIZE] = {0};
    unsigned char c[EVP_MAX_MD_SIZE];
    unsigned int outlen, tmplen;

    /* Simply digest whole input. */
    T(ctx = EVP_MD_CTX_new());
    T(EVP_DigestInit_ex(ctx, type, NULL));
    if (mac)
	T(EVP_MD_CTX_ctrl(ctx, EVP_MD_CTRL_SET_KEY, sizeof(K), (void *)K));
    T(EVP_DigestUpdate(ctx, pt, sizeof(pt)));
    T(EVP_DigestFinal_ex(ctx, b, &tmplen));
    save = ctx; /* will be not freed while cloning */

    /* cloned digest */
    EVP_MD_CTX_reset(ctx); /* test double reset */
    EVP_MD_CTX_reset(ctx);
    T(EVP_DigestInit_ex(ctx, type, NULL));
    if (mac)
	T(EVP_MD_CTX_ctrl(ctx, EVP_MD_CTRL_SET_KEY, sizeof(K), (void *)K));
    printf(" cloned contexts: ");
    memset(c, 0, sizeof(c));
    int i;
    for (i = 0; i < TEST_SIZE / STEP_SIZE; i++) {
	/* Clone and continue digesting next part of input. */
	EVP_MD_CTX *copy;
	T(copy = EVP_MD_CTX_new());
	T(EVP_MD_CTX_copy_ex(copy, ctx));

	/* rolling */
	if (save != ctx)
	    EVP_MD_CTX_free(ctx);
	ctx = copy;

	T(EVP_DigestUpdate(ctx, pt + STEP_SIZE * i, STEP_SIZE));
    }
    outlen = i * STEP_SIZE;
    T(EVP_DigestFinal_ex(ctx, c, &tmplen));
    /* Should be same as the simple digest. */
    TEST_ASSERT(outlen != TEST_SIZE || memcmp(c, b, EVP_MAX_MD_SIZE));
    EVP_MD_CTX_free(ctx);
    if (test) {
	printf("  b[%d] = ", outlen);
	hexdump(b, outlen);
	printf("  c[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    /* Resume original context, what if it's damaged? */
    printf("    base context: ");
    memset(c, 0, sizeof(c));
    T(EVP_DigestUpdate(save, pt, sizeof(pt)));
    T(EVP_DigestFinal_ex(save, c, &tmplen));
    TEST_ASSERT(outlen != TEST_SIZE || memcmp(c, b, EVP_MAX_MD_SIZE));
    EVP_MD_CTX_free(save);
    if (test) {
	printf("  b[%d] = ", outlen);
	hexdump(b, outlen);
	printf("  c[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    return ret;
}

static int test_contexts_digest(const char *name)
{
    EVP_MD *type;
    ERR_set_mark();
    T((type = (EVP_MD *)EVP_get_digestbyname(name))
      || (type = EVP_MD_fetch(NULL, name, NULL)));
    ERR_pop_to_mark();

    printf(cBLUE "Digest test for %s" cNORM "\n", name);
    int ret = test_contexts_digest_or_legacy_mac(type, 0);
    EVP_MD_free(type);
    return ret;
}

static int test_contexts_mac(const char *name)
{
    int ret = 0, test = 0;
    unsigned char K[32] = {1};
    const EVP_MD *type = EVP_get_digestbyname(name);
    EVP_MAC *mac;

    if (type) {
        printf(cBLUE "Mac via EVP_MD test for %s" cNORM "\n", name);
        return test_contexts_digest_or_legacy_mac(type, 1);
    }

    T(mac = EVP_MAC_fetch(NULL, name, NULL));
    printf(cBLUE "Mac test for %s" cNORM "\n", name);

    /* produce base mac */
    EVP_MAC_CTX *ctx;
    unsigned char pt[TEST_SIZE] = {1};
    unsigned char b[EVP_MAX_MD_SIZE] = {0};
    unsigned char c[EVP_MAX_MD_SIZE] = {0};
    size_t outlen, tmplen;

    /* Simply mac whole input. */
    T(ctx = EVP_MAC_CTX_new(mac));
    T(EVP_MAC_init(ctx, K, sizeof(K), NULL));
    T(EVP_MAC_update(ctx, pt, sizeof(pt)));
    T(EVP_MAC_final(ctx, b, &tmplen, sizeof(b)));
    EVP_MAC_CTX_free(ctx);

    /* Mac with rolling input. */
    printf(" cloned contexts: ");
    T(ctx = EVP_MAC_CTX_new(mac));
    T(EVP_MAC_init(ctx, K, sizeof(K), NULL));
    int i;
    for (i = 0; i < TEST_SIZE / STEP_SIZE; i++) {
	T(EVP_MAC_update(ctx, pt + STEP_SIZE * i, STEP_SIZE));
    }
    outlen = i * STEP_SIZE;
    T(EVP_MAC_final(ctx, c, &tmplen, sizeof(c)));
    EVP_MAC_CTX_free(ctx);
    EVP_MAC_free(mac);

    /* Rolling mac should give the same result as the simple mac. */
    TEST_ASSERT(outlen != TEST_SIZE || memcmp(c, b, EVP_MAX_MD_SIZE));

    if (test) {
        printf("  b[%d] = ", (int)outlen);
	hexdump(b, outlen);
        printf("  c[%d] = ", (int)outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    return ret;
}

static struct testcase_cipher {
    const char *name;
    int acpkm;
} testcases_ciphers[] = {
    { SN_id_Gost28147_89, },
    { SN_gost89_cnt, },
    { SN_gost89_cnt_12, },
    { SN_gost89_cbc, },
    { SN_grasshopper_ecb, },
    { SN_grasshopper_cbc, },
    { SN_grasshopper_cfb, },
    { SN_grasshopper_ofb, },
    { SN_grasshopper_ctr, },
    { SN_magma_cbc, },
    { SN_magma_ctr, },
    { SN_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm, 256 / 8 },
    { 0 },
};

static struct testcase_digest {
    const char *name;
    int mac;
} testcases_digests[] = {
    { SN_id_GostR3411_94, },
    { SN_id_Gost28147_89_MAC, 1 },
    { SN_id_GostR3411_2012_256, },
    { SN_id_GostR3411_2012_512, },
    { SN_gost_mac_12, 1 },
    { SN_magma_mac, 1 },
    { SN_grasshopper_mac, 1 },
    { SN_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm_omac, 1 },
    { 0 },
};
int main(int argc, char **argv)
{
    int ret = 0;

    OPENSSL_add_all_algorithms_conf();

    const struct testcase_cipher *tc;
    for (tc = testcases_ciphers; tc->name; tc++) {
	ret |= test_contexts_cipher(tc->name, 1, tc->acpkm);
	ret |= test_contexts_cipher(tc->name, 0, tc->acpkm);
    }
    const struct testcase_digest *td;
    for (td = testcases_digests; td->name; td++) {
        if (td->mac)
            ret |= test_contexts_mac(td->name);
        else
            ret |= test_contexts_digest(td->name);
    }

    if (ret)
	printf(cDRED "= Some tests FAILED!" cNORM "\n");
    else
	printf(cDGREEN "= All tests passed!" cNORM "\n");
    return ret;
}
