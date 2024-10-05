/*
 * Test "Recommendations for standardization R 1323565.1.026 - 2019"
 * authentivated encryption block cipher operation modes
 *
 * Copyright (C) 2019-2020 Vitaly Chikunov <vt@altlinux.org>. All Rights Reserved.
 * Copyright (c) 2020-2021 JSC "NPK "Kryptonite" <i.kirillov@kryptonite.ru>.
 * Code based on test_ciphers.c from master branch.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#include <openssl/engine.h>
#include <openssl/evp.h>
#include <string.h>

#include "gost_grasshopper_cipher.h"
#include "gost_gost2015.h"
#if defined _MSC_VER
# include <malloc.h>
# define alloca _alloca
#elif defined __linux__
# include <alloca.h>
#endif

#define T(e) ({ \
    if (!(e)) {\
	ERR_print_errors_fp(stderr);\
	OpenSSLDie(__FILE__, __LINE__, #e);\
    } \
})

#define TEST_ASSERT(e) {if ((test = (e))) \
		 printf("Test FAILED\n"); \
	     else \
		 printf("Test passed\n");}


/* MGM-Encrypt/MGM-decrypt test data from "R 1323565.1.026-2019" */

const unsigned char gh_key[32] = {
    0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
};

const unsigned char gh_nonce[16] = {
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88
};

const unsigned char gh_adata[41] = {
    0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0xEA, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05
};

const unsigned char gh_pdata[67] = {
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88,
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xEE, 0xFF, 0x0A,
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xEE, 0xFF, 0x0A, 0x00,
    0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xEE, 0xFF, 0x0A, 0x00, 0x11,
    0xAA, 0xBB, 0xCC
};

const unsigned char gh_e_cdata[67] = {
    0xA9, 0x75, 0x7B, 0x81, 0x47, 0x95, 0x6E, 0x90, 0x55, 0xB8, 0xA3, 0x3D, 0xE8, 0x9F, 0x42, 0xFC,
    0x80, 0x75, 0xD2, 0x21, 0x2B, 0xF9, 0xFD, 0x5B, 0xD3, 0xF7, 0x06, 0x9A, 0xAD, 0xC1, 0x6B, 0x39,
    0x49, 0x7A, 0xB1, 0x59, 0x15, 0xA6, 0xBA, 0x85, 0x93, 0x6B, 0x5D, 0x0E, 0xA9, 0xF6, 0x85, 0x1C,
    0xC6, 0x0C, 0x14, 0xD4, 0xD3, 0xF8, 0x83, 0xD0, 0xAB, 0x94, 0x42, 0x06, 0x95, 0xC7, 0x6D, 0xEB,
    0x2C, 0x75, 0x52
};

const unsigned char gh_e_tag[16] = {
    0xCF, 0x5D, 0x65, 0x6F, 0x40, 0xC3, 0x4F, 0x5C, 0x46, 0xE8, 0xBB, 0x0E, 0x29, 0xFC, 0xDB, 0x4C
};

const unsigned char mg_key[32] = {
    0xFF, 0xee, 0xDD, 0xcc, 0xbb, 0xaa, 0x99, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00,
    0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xff
};

const unsigned char mg_nonce[8] = {
    0x12, 0xDE, 0xF0, 0x6B, 0x3C, 0x13, 0x0A, 0x59
};

const unsigned char mg_adata[41] = {
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0xea
};

const unsigned char mg_pdata[67] = {
    0xFF, 0xee, 0xDD, 0xcc, 0xbb, 0xaa, 0x99, 0x88, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xee, 0xFF, 0x0A, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x99, 0xaa, 0xbb, 0xcc, 0xee, 0xFF, 0x0a, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
    0xaa, 0xbb, 0xcc, 0xee, 0xFF, 0x0a, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99,
    0xaa, 0xbb, 0xcc
};

const unsigned char mg_e_cdata[67] = {
    0xc7, 0x95, 0x06, 0x6c, 0x5f, 0x9e, 0xa0, 0x3b, 0x85, 0x11, 0x33, 0x42, 0x45, 0x91, 0x85, 0xae,
    0x1f, 0x2e, 0x00, 0xd6, 0xbf, 0x2b, 0x78, 0x5d, 0x94, 0x04, 0x70, 0xb8, 0xbb, 0x9c, 0x8e, 0x7d,
    0x9a, 0x5d, 0xd3, 0x73, 0x1f, 0x7d, 0xdc, 0x70, 0xec, 0x27, 0xcb, 0x0a, 0xce, 0x6f, 0xa5, 0x76,
    0x70, 0xf6, 0x5c, 0x64, 0x6a, 0xbb, 0x75, 0xd5, 0x47, 0xaa, 0x37, 0xc3, 0xbc, 0xb5, 0xc3, 0x4e,
    0x03, 0xbb, 0x9c
};

const unsigned char mg_e_tag[8] = {
    0xa7, 0x92, 0x80, 0x69, 0xaa, 0x10, 0xfd, 0x10
};


static struct testcase {
    const char *sn;
    const unsigned char *key;
    const unsigned char *nonce;
    size_t nonce_len;
    const unsigned char *aad;
    size_t aad_len;
    const unsigned char *plaintext;
    size_t ptext_len;
    const unsigned char *expected;
    const unsigned char *expected_tag;
} testcases[] = {
    {
        .sn = SN_kuznyechik_mgm,
        .key = gh_key,
        .nonce = gh_nonce,
        .nonce_len = sizeof(gh_nonce),
        .aad = gh_adata,
        .aad_len = sizeof(gh_adata),
        .plaintext = gh_pdata,
        .ptext_len = sizeof(gh_pdata),
        .expected = gh_e_cdata,
        .expected_tag = gh_e_tag
    },
    {
        .sn = SN_magma_mgm,
        .key = mg_key,
        .nonce = mg_nonce,
        .nonce_len = sizeof(mg_nonce),
        .aad = mg_adata,
        .aad_len = sizeof(mg_adata),
        .plaintext = mg_pdata,
        .ptext_len = sizeof(mg_pdata),
        .expected = mg_e_cdata,
        .expected_tag = mg_e_tag
    },
    { 0 }
};

static int test_block(const EVP_CIPHER *ciph, const char *name, const unsigned char *nonce, size_t nlen,
                      const unsigned char *aad, size_t alen, const unsigned char *ptext, size_t plen,
                      const unsigned char *exp_ctext, const unsigned char *exp_tag,
                      const unsigned char * key, int small)
{
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    unsigned char *c = alloca(plen);
    int tag_len = nlen;
    unsigned char *t = alloca(tag_len);
    int outlen1, outlen2, tmplen;
    int ret = 0, rv, test, i;

    OPENSSL_assert(ctx);
    printf("Encryption test %s [%s]: ", name, small ? "small chunks" : "big chunks");

    // test encrypt
    EVP_CIPHER_CTX_init(ctx);
    EVP_EncryptInit_ex(ctx, ciph, NULL, NULL, NULL);                    // Set cipher type and mode
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, nlen, NULL);      // Set IV length
    EVP_EncryptInit_ex(ctx, NULL, NULL, key, nonce);                    // Initialise key and IV
    memset(c, 0, plen);
    if (!small) {
        // test big chunks
        EVP_EncryptUpdate(ctx, NULL, &outlen1, aad, alen);              // Zero or more calls to specify any AAD
        EVP_EncryptUpdate(ctx, c, &outlen2, ptext, plen);               // Encrypt plaintext
    } else {
        // test small chunks
        outlen1 = outlen2 = 0;
        unsigned char *p;
        for (i = 0; i < alen; i++) {
            EVP_EncryptUpdate(ctx, NULL, &tmplen, aad + i, 1);
            outlen1 += tmplen;
        }
        for (i = 0, p = c; i < plen; i++) {
            EVP_EncryptUpdate(ctx, p, &tmplen, ptext + i, 1);
            p += tmplen;
            outlen2 += tmplen;
        }
    }
    EVP_EncryptFinal_ex(ctx, c, &tmplen);
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, tag_len, t);
    EVP_CIPHER_CTX_cleanup(ctx);

    TEST_ASSERT(outlen1 != alen || outlen2 != plen ||
                memcmp(c, exp_ctext, plen) ||
                memcmp(t, exp_tag, tag_len));
    ret |= test;


    // test decrtypt
    printf("Decryption test %s [%s]: ", name, small ? "small chunks" : "big chunks");
    EVP_CIPHER_CTX_init(ctx);
    EVP_DecryptInit_ex(ctx, ciph, NULL, NULL, NULL);
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, nlen, NULL);
    EVP_DecryptInit_ex(ctx, NULL, NULL, key, nonce);
    memset(c, 0, plen);
    if (!small) {
        // test big chunks
        EVP_DecryptUpdate(ctx, NULL, &outlen1, aad, alen);
        EVP_DecryptUpdate(ctx, c, &outlen2, exp_ctext, plen);
    } else {
        // test small chunks
        outlen1 = outlen2 = 0;
        unsigned char *p;
        for (i = 0; i < alen; i++) {
            EVP_DecryptUpdate(ctx, NULL, &tmplen, aad + i, 1);
            outlen1 += tmplen;
        }
        for (i = 0, p = c; i < plen; i++) {
            EVP_DecryptUpdate(ctx, p, &tmplen, exp_ctext + i, 1);
            p += tmplen;
            outlen2 += tmplen;
        }
    }
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, tag_len, (void *)exp_tag);
    rv = EVP_DecryptFinal_ex(ctx, c, &tmplen);
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);

    TEST_ASSERT(outlen1 != alen || outlen2 != plen ||
                memcmp(c, ptext, plen) || rv != 1);
    ret |= test;

    return ret;
}

int main(void)
{
    int ret = 0;
    const struct testcase *t;

    OPENSSL_add_all_algorithms_conf();

    for (t = testcases; t->sn; t++) {
        int small;
        const EVP_CIPHER *ciph_eng = EVP_get_cipherbyname(t->sn);
        EVP_CIPHER *ciph_prov = EVP_CIPHER_fetch(NULL, t->sn, NULL);
        const EVP_CIPHER *ciph = ciph_eng ? ciph_eng : ciph_prov;
        const char *name;
        if (!ciph) {
            printf("failed to load %s\n", t->sn);
            return 1;
        }
        name = EVP_CIPHER_name(ciph);

        printf("Tests for %s\n", name);
        for (small = 0; small <= 1; small++)
            ret |= test_block(ciph, name, t->nonce, t->nonce_len,
                              t->aad, t->aad_len, t->plaintext, t->ptext_len,
                              t->expected, t->expected_tag, t->key, small);
        EVP_CIPHER_free(ciph_prov);
    }

    if (ret) {
        printf("Some tests FAILED!\n");
    } else {
        printf("All tests passed!\n");
    }
    return ret;
}
