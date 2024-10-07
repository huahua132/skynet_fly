/*
 * Test GOST 34.10 Sign/Verify operation for every curve parameter
 *
 * Copyright (C) 2019 vt@altlinux.org. All Rights Reserved.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
#include "gost_lcl.h"
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#include <openssl/obj_mac.h>
#include <openssl/ec.h>
#include <openssl/bn.h>
#include <openssl/store.h>
#include <openssl/engine.h>
#include <string.h>
#include <stdlib.h>

#define T(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        OpenSSLDie(__FILE__, __LINE__, #e); \
    }
#define TE(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        fprintf(stderr, "Error at %s:%d %s\n", __FILE__, __LINE__, #e); \
        return -1; \
    }

#define cRED	"\033[1;31m"
#define cDRED	"\033[0;31m"
#define cGREEN	"\033[1;32m"
#define cDGREEN	"\033[0;32m"
#define cBLUE	"\033[1;34m"
#define cDBLUE	"\033[0;34m"
#define cCYAN	"\033[1;36m"
#define cNORM	"\033[m"
#define TEST_ASSERT(e) {if ((test = (e))) \
		 printf(cRED "  Test FAILED" cNORM "\n"); \
	     else \
		 printf(cGREEN "  Test passed" cNORM "\n");}

struct test_sign {
    const char *name;
    int nid;
    size_t bits;
    const char *paramset;
};

#define D(x,y,z) { .name = #x, .nid = x, .bits = y, .paramset = z }
static struct test_sign test_signs[] = {
    D(NID_id_GostR3410_2001_CryptoPro_A_ParamSet, 256, "A"),
    D(NID_id_GostR3410_2001_CryptoPro_B_ParamSet, 256, "B"),
    D(NID_id_GostR3410_2001_CryptoPro_C_ParamSet, 256, "C"),
    D(NID_id_tc26_gost_3410_2012_256_paramSetA, 256, "TCA"),
    D(NID_id_tc26_gost_3410_2012_256_paramSetB, 256, "TCB"),
    D(NID_id_tc26_gost_3410_2012_256_paramSetC, 256, "TCC"),
    D(NID_id_tc26_gost_3410_2012_256_paramSetD, 256, "TCD"),
    D(NID_id_tc26_gost_3410_2012_512_paramSetA,   512, "A"),
    D(NID_id_tc26_gost_3410_2012_512_paramSetB,   512, "B"),
    D(NID_id_tc26_gost_3410_2012_512_paramSetC,   512, "C"),
    0
};
#undef D

static void hexdump(const void *ptr, size_t len)
{
    const unsigned char *p = ptr;
    size_t i, j;

    for (i = 0; i < len; i += j) {
	for (j = 0; j < 16 && i + j < len; j++)
	    printf("%s %02x", j? "" : "\n", p[i + j]);
    }
    printf("\n");
}

static void print_test_tf(int err, int val, const char *t, const char *f)
{
    if (err == 1)
	printf(cGREEN "%s" cNORM "\n", t);
    else
	printf(cRED "%s [%d]" cNORM "\n", f, val);
}

static void print_test_result(int err)
{
    if (err == 1)
	printf(cGREEN "success" cNORM "\n");
    else if (err == 0)
	printf(cRED "failure" cNORM "\n");
    else
	ERR_print_errors_fp(stderr);
}

static int test_sign(struct test_sign *t)
{
    int ret = 0, err;
    size_t len = t->bits / 8;

    printf(cBLUE "Test %s:" cNORM "\n", t->name);

    /* Signature type from size. */
    int type = 0;
    const char *algname = NULL;
    switch (t->bits) {
	case 256:
	    type = NID_id_GostR3410_2012_256;
	    algname = "gost2012_256";
	    break;
	case 512:
	    type = NID_id_GostR3410_2012_512;
	    algname = "gost2012_512";
	    break;
	default:
	    return -1;
    }

    /* Keygen. */
    EVP_PKEY *pkey;
    T(pkey = EVP_PKEY_new());
    TE(EVP_PKEY_set_type(pkey, type));
    EVP_PKEY_CTX *ctx;
    T(ctx = EVP_PKEY_CTX_new(pkey, NULL));
    T(EVP_PKEY_keygen_init(ctx));
    T(EVP_PKEY_CTX_ctrl(ctx, type, -1, EVP_PKEY_CTRL_GOST_PARAMSET, t->nid, NULL));
    EVP_PKEY *priv_key = NULL;
    err = EVP_PKEY_keygen(ctx, &priv_key);
    printf("\tEVP_PKEY_keygen:\t");
    print_test_result(err);
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(pkey);
    if (err != 1)
	return -1;

    /* Convert to PEM and back. */
    BIO *bp;
    T(bp = BIO_new(BIO_s_secmem()));
    T(PEM_write_bio_PrivateKey(bp, priv_key, NULL, NULL, 0, NULL, NULL));
    pkey = NULL;
    T(PEM_read_bio_PrivateKey(bp, &pkey, NULL, NULL));
    printf("\tPEM_read_bio_PrivateKey:");
    /* Yes, it compares only public part. */
    err = !EVP_PKEY_cmp(priv_key, pkey);
    print_test_result(!err);
    ret |= err;
    EVP_PKEY_free(pkey);

    /* Convert to DER and back, using _PrivateKey_bio API. */
    T(BIO_reset(bp));
    T(i2d_PrivateKey_bio(bp, priv_key));
    T(d2i_PrivateKey_bio(bp, &pkey));
    printf("\td2i_PrivateKey_bio:\t");
    err = !EVP_PKEY_cmp(priv_key, pkey);
    print_test_result(!err);
    ret |= err;
    EVP_PKEY_free(pkey);

#if OPENSSL_VERSION_MAJOR >= 3
    /* Try d2i_PrivateKey_ex_bio, added in 3.0. */
    T(BIO_reset(bp));
    T(i2d_PrivateKey_bio(bp, priv_key));
    T(d2i_PrivateKey_ex_bio(bp, &pkey, NULL, NULL));
    printf("\td2i_PrivateKey_ex_bio:\t");
    err = !EVP_PKEY_cmp(priv_key, pkey);
    print_test_result(!err);
    ret |= err;
    EVP_PKEY_free(pkey);
#endif

    /* Convert to DER and back, using OSSL_STORE API. */
    T(BIO_reset(bp));
    T(i2d_PrivateKey_bio(bp, priv_key));
    printf("\tOSSL_STORE_attach:\t");
    fflush(stdout);
    pkey = NULL;
    OSSL_STORE_CTX *cts;
    T(cts = OSSL_STORE_attach(bp, "file", NULL, NULL, NULL, NULL, NULL, NULL, NULL));
    for (;;) {
	OSSL_STORE_INFO *info = OSSL_STORE_load(cts);
	if (!info) {
	    ERR_print_errors_fp(stderr);
	    T(OSSL_STORE_eof(cts));
	    break;
	}
	if (OSSL_STORE_INFO_get_type(info) == OSSL_STORE_INFO_PKEY) {
	    T((pkey = OSSL_STORE_INFO_get1_PKEY(info)));
	}
	OSSL_STORE_INFO_free(info);
    }
    OSSL_STORE_close(cts);
    if (pkey) {
	err = !EVP_PKEY_cmp(priv_key, pkey);
	print_test_result(!err);
	ret |= err;
	EVP_PKEY_free(pkey);
    } else
	printf(cCYAN "skipped" cNORM "\n");
    BIO_free(bp);

    /* Convert to DER and back, using memory API. */
    unsigned char *kptr = NULL;
    int klen;
    T(klen = i2d_PrivateKey(priv_key, &kptr));
    const unsigned char *tptr = kptr; /* will be moved by d2i_PrivateKey */
    pkey = NULL;
    T(d2i_PrivateKey(type, &pkey, &tptr, klen));
    printf("\td2i_PrivateKey:\t\t");
    err = !EVP_PKEY_cmp(priv_key, pkey);
    print_test_result(!err);
    ret |= err;
    EVP_PKEY_free(pkey);
    OPENSSL_free(kptr);

    /* Create another key using string interface. */
    EVP_PKEY *key1;
    T(key1 = EVP_PKEY_new());
    T(EVP_PKEY_set_type_str(key1, algname, strlen(algname)));
    EVP_PKEY_CTX *ctx1;
    T(ctx1 = EVP_PKEY_CTX_new(key1, NULL));
    T(EVP_PKEY_keygen_init(ctx1));
    T(EVP_PKEY_CTX_ctrl_str(ctx1, "paramset", t->paramset));
    EVP_PKEY *key2 = NULL;
    err = EVP_PKEY_keygen(ctx1, &key2);
    printf("\tEVP_PKEY_*_str:\t\t");
    print_test_result(err);
    ret |= !err;

    /* Check if key type and curve_name match expected values. */
    int id = EVP_PKEY_id(key2);
    err = id == type;
    printf("\tEVP_PKEY_id (%d):\t", type);
    print_test_tf(err, id, "match", "mismatch");
    ret |= !err;

    const EC_KEY *ec = EVP_PKEY_get0(key2);
    const EC_GROUP *group = EC_KEY_get0_group(ec);
    int curve_name = EC_GROUP_get_curve_name(group);
    err = curve_name == t->nid;
    printf("\tcurve_name (%d):\t", t->nid);
    print_test_tf(err, curve_name, "match", "mismatch");
    ret |= !err;

    /* Compare both keys.
     * Parameters should match, public keys should mismatch.
    */
    err = EVP_PKEY_cmp_parameters(priv_key, key2);
    printf("\tEVP_PKEY_cmp_parameters:");
    print_test_tf(err, err, "success", "failure");
    ret |= err != 1;

    err = EVP_PKEY_cmp(priv_key, key2);
    err = (err < 0) ? err : !err;
    printf("\tEVP_PKEY_cmp:\t\t");
    print_test_tf(err, err, "differ (good)", "equal (error)");
    ret |= err != 1;
    EVP_PKEY_CTX_free(ctx1);
    EVP_PKEY_free(key1);

    /*
     * Prepare for sign testing.
     */
    size_t siglen = EVP_PKEY_size(priv_key);
    unsigned char *sig;
    T(sig = OPENSSL_malloc(siglen));
    unsigned char *hash;
    T(hash = OPENSSL_zalloc(len));
    T(ctx = EVP_PKEY_CTX_new(priv_key, NULL));

    /* Sign. */
    T(EVP_PKEY_sign_init(ctx));
    err = EVP_PKEY_sign(ctx, sig, &siglen, hash, len);
    printf("\tEVP_PKEY_sign:\t\t");
    print_test_result(err);
    ret |= err != 1;

    /* Non-determinism test.
     * Check that different signatures for the same data
     * are not equal. */
    unsigned char *sig2;
    T(sig2 = OPENSSL_malloc(siglen));
    TE(EVP_PKEY_sign(ctx, sig2, &siglen, hash, len) == 1);
    printf("\tNon-determinism:\t");
    err = !!memcmp(sig, sig2, siglen);
    print_test_result(err);
    ret |= err != 1;
    OPENSSL_free(sig2);

    /* Verify. */
    T(EVP_PKEY_verify_init(ctx));
    hash[0]++; /* JFF */
    err = EVP_PKEY_verify(ctx, sig, siglen, hash, len);
    printf("\tEVP_PKEY_verify:\t");
    print_test_result(err);
    ret |= err != 1;

    /* False positive Verify. */
    T(EVP_PKEY_verify_init(ctx));
    hash[0]++;
    err = EVP_PKEY_verify(ctx, sig, siglen, hash, len);
    err = (err < 0) ? err : !err;
    printf("\tFalse positive test:\t");
    print_test_result(err);
    ret |= err != 1;

    EVP_PKEY_CTX_free(ctx);
    OPENSSL_free(sig);
    OPENSSL_free(hash);
    EVP_PKEY_free(priv_key);
    EVP_PKEY_free(key2);

    return ret;
}

int main(int argc, char **argv)
{
    int ret = 0;

    OPENSSL_add_all_algorithms_conf();

    struct test_sign *sp;
    for (sp = test_signs; sp->name; sp++)
	ret |= test_sign(sp);

    if (ret)
	printf(cDRED "= Some tests FAILED!" cNORM "\n");
    else
	printf(cDGREEN "= All tests passed!" cNORM "\n");
    return ret;
}
