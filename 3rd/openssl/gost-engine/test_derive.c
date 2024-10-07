/*
 * Test derive operations
 *
 * Copyright (C) 2020 Vitaly Chikunov <vt@altlinux.org>. All Rights Reserved.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
#include <openssl/ec.h>
#include <openssl/engine.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <stdlib.h>
#include <string.h>
#include "gost_lcl.h"

#define T(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        OpenSSLDie(__FILE__, __LINE__, #e); \
    }

#define cRED    "\033[1;31m"
#define cDRED   "\033[0;31m"
#define cGREEN  "\033[1;32m"
#define cDGREEN "\033[0;32m"
#define cBLUE   "\033[1;34m"
#define cDBLUE  "\033[0;34m"
#define cCYAN   "\033[1;36m"
#define cNORM   "\033[m"
#define TEST_ASSERT(e) {if ((test = (e))) \
                 printf(cRED "  Test FAILED" cNORM "\n"); \
             else \
                 printf(cGREEN "  Test passed" cNORM "\n");}

#ifndef OSSL_NELEM
# define OSSL_NELEM(x) (sizeof(x)/sizeof((x)[0]))
#endif

const char party_a_priv[] =
    "\xc9\x90\xec\xd9\x72\xfc\xe8\x4e\xc4\xdb\x02\x27\x78\xf5\x0f\xca"
    "\xc7\x26\xf4\x67\x08\x38\x4b\x8d\x45\x83\x04\x96\x2d\x71\x47\xf8"
    "\xc2\xdb\x41\xce\xf2\x2c\x90\xb1\x02\xf2\x96\x84\x04\xf9\xb9\xbe"
    "\x6d\x47\xc7\x96\x92\xd8\x18\x26\xb3\x2b\x8d\xac\xa4\x3c\xb6\x67";
const char party_a_pub[] =
    "\xaa\xb0\xed\xa4\xab\xff\x21\x20\x8d\x18\x79\x9f\xb9\xa8\x55\x66"
    "\x54\xba\x78\x30\x70\xeb\xa1\x0c\xb9\xab\xb2\x53\xec\x56\xdc\xf5"
    "\xd3\xcc\xba\x61\x92\xe4\x64\xe6\xe5\xbc\xb6\xde\xa1\x37\x79\x2f"
    "\x24\x31\xf6\xc8\x97\xeb\x1b\x3c\x0c\xc1\x43\x27\xb1\xad\xc0\xa7"
    "\x91\x46\x13\xa3\x07\x4e\x36\x3a\xed\xb2\x04\xd3\x8d\x35\x63\x97"
    "\x1b\xd8\x75\x8e\x87\x8c\x9d\xb1\x14\x03\x72\x1b\x48\x00\x2d\x38"
    "\x46\x1f\x92\x47\x2d\x40\xea\x92\xf9\x95\x8c\x0f\xfa\x4c\x93\x75"
    "\x64\x01\xb9\x7f\x89\xfd\xbe\x0b\x5e\x46\xe4\xa4\x63\x1c\xdb\x5a";
const char party_b_priv[] =
    "\x48\xc8\x59\xf7\xb6\xf1\x15\x85\x88\x7c\xc0\x5e\xc6\xef\x13\x90"
    "\xcf\xea\x73\x9b\x1a\x18\xc0\xd4\x66\x22\x93\xef\x63\xb7\x9e\x3b"
    "\x80\x14\x07\x0b\x44\x91\x85\x90\xb4\xb9\x96\xac\xfe\xa4\xed\xfb"
    "\xbb\xcc\xcc\x8c\x06\xed\xd8\xbf\x5b\xda\x92\xa5\x13\x92\xd0\xdb";
const char party_b_pub[] =
    "\x19\x2f\xe1\x83\xb9\x71\x3a\x07\x72\x53\xc7\x2c\x87\x35\xde\x2e"
    "\xa4\x2a\x3d\xbc\x66\xea\x31\x78\x38\xb6\x5f\xa3\x25\x23\xcd\x5e"
    "\xfc\xa9\x74\xed\xa7\xc8\x63\xf4\x95\x4d\x11\x47\xf1\xf2\xb2\x5c"
    "\x39\x5f\xce\x1c\x12\x91\x75\xe8\x76\xd1\x32\xe9\x4e\xd5\xa6\x51"
    "\x04\x88\x3b\x41\x4c\x9b\x59\x2e\xc4\xdc\x84\x82\x6f\x07\xd0\xb6"
    "\xd9\x00\x6d\xda\x17\x6c\xe4\x8c\x39\x1e\x3f\x97\xd1\x02\xe0\x3b"
    "\xb5\x98\xbf\x13\x2a\x22\x8a\x45\xf7\x20\x1a\xba\x08\xfc\x52\x4a"
    "\x2d\x77\xe4\x3a\x36\x2a\xb0\x22\xad\x40\x28\xf7\x5b\xde\x3b\x79";

struct test_derive {
    const char *descr; /* Source of test vector. */
    int dgst_nid;      /* VKO mode */
    int key_nid;
    int param_nid;     /* Curve id. */
    const char *ukm;   /* User Keying Material. */
    int ukm_len;
    const char *key_a_priv;
    const char *key_a_pub;
    const char *key_b_priv;
    const char *key_b_pub;
    const char *kek;   /* Key Encryption Key. Output. */
    int kek_len;
} derive_tests[] = {
    {
        .descr      = "VKO_GOSTR3410_2012_256 from R 50.1.113-2016 A.9 (p.18)",
        .dgst_nid   = NID_id_GostR3411_2012_256,
        .key_nid    = NID_id_GostR3410_2012_512,
        .param_nid  = NID_id_tc26_gost_3410_2012_512_paramSetA,
        .key_a_priv = party_a_priv,
        .key_a_pub  = party_a_pub,
        .key_b_priv = party_b_priv,
        .key_b_pub  = party_b_pub,
        .ukm        = "\x1d\x80\x60\x3c\x85\x44\xc7\x27",
        .ukm_len    = 8,
        .kek =
            "\xc9\xa9\xa7\x73\x20\xe2\xcc\x55\x9e\xd7\x2d\xce\x6f\x47\xe2\x19"
            "\x2c\xce\xa9\x5f\xa6\x48\x67\x05\x82\xc0\x54\xc0\xef\x36\xc2\x21",
        .kek_len = 32,
    },
    {
        .descr      = "VKO_GOSTR3410_2012_512 from R 50.1.113-2016 A.10 (p.19)",
        .dgst_nid   = NID_id_GostR3411_2012_512,
        .key_nid    = NID_id_GostR3410_2012_512,
        .param_nid  = NID_id_tc26_gost_3410_2012_512_paramSetA,
        .key_a_priv = party_a_priv,
        .key_a_pub  = party_a_pub,
        .key_b_priv = party_b_priv,
        .key_b_pub  = party_b_pub,
        .ukm        = "\x1d\x80\x60\x3c\x85\x44\xc7\x27",
        .ukm_len    = 8,
        .kek =
            "\x79\xf0\x02\xa9\x69\x40\xce\x7b\xde\x32\x59\xa5\x2e\x01\x52\x97"
            "\xad\xaa\xd8\x45\x97\xa0\xd2\x05\xb5\x0e\x3e\x17\x19\xf9\x7b\xfa"
            "\x7e\xe1\xd2\x66\x1f\xa9\x97\x9a\x5a\xa2\x35\xb5\x58\xa7\xe6\xd9"
            "\xf8\x8f\x98\x2d\xd6\x3f\xc3\x5a\x8e\xc0\xdd\x5e\x24\x2d\x3b\xdf",
        .kek_len = 64,
    },
};

static EVP_PKEY *load_private_key(int key_nid, int param_nid, const char *pk,
                                  const char *pub)
{

    EVP_PKEY_CTX *ctx;
    T(ctx = EVP_PKEY_CTX_new_id(key_nid, NULL));
    T(EVP_PKEY_paramgen_init(ctx));
    T(EVP_PKEY_CTX_ctrl(ctx, -1, -1, EVP_PKEY_CTRL_GOST_PARAMSET, param_nid,
                        NULL));
    EVP_PKEY *key = NULL;
    T((EVP_PKEY_paramgen(ctx, &key)) == 1);
    EVP_PKEY_CTX_free(ctx);

    EC_KEY *ec;
    T(ec = EVP_PKEY_get0(key));

    const int len = EVP_PKEY_bits(key) / 8;
    BN_CTX *bc;
    T(bc = BN_CTX_secure_new());
    BN_CTX_start(bc);
    const EC_GROUP *group = EC_KEY_get0_group(ec);
    EC_POINT *pkey = NULL;
    if (pk) {
        /* Read private key. */
        BIGNUM *d = NULL;
        T(d = BN_lebin2bn((const unsigned char *)pk, len, NULL));
        T(EC_KEY_set_private_key(ec, d));

        /* Compute public key. */
        T(pkey = EC_POINT_new(group));
        T(EC_POINT_mul(group, pkey, d, NULL, NULL, bc));
        BN_free(d);
        T(EC_KEY_set_public_key(ec, pkey));
    } else {
        /* Read public key. */
        BIGNUM *x, *y;
        T(x = BN_lebin2bn((const unsigned char *)pub, len, NULL));
        T(y = BN_lebin2bn((const unsigned char *)pub + len, len, NULL));
        EC_POINT *xy = EC_POINT_new(group);
        T(EC_POINT_set_affine_coordinates(group, xy, x, y, bc));
        BN_free(x);
        BN_free(y);
        T(EC_KEY_set_public_key(ec, xy));
        EC_POINT_free(xy);
    }

#ifdef DEBUG
    BIO *bp = BIO_new_fd(1, BIO_NOCLOSE);
    if (pk)
        PEM_write_bio_PrivateKey(bp, key, NULL, NULL, 0, NULL, NULL);
    PEM_write_bio_PUBKEY(bp, key);
    BIO_free(bp);
#endif

    /* Verify public key. */
    if (pk && pub) {
        BIGNUM *x, *y;
        T(x = BN_lebin2bn((const unsigned char *)pub, len, NULL));
        T(y = BN_lebin2bn((const unsigned char *)pub + len, len, NULL));
        EC_POINT *xy = EC_POINT_new(group);
        T(EC_POINT_set_affine_coordinates(group, xy, x, y, bc));
        BN_free(x);
        BN_free(y);
        if (EC_POINT_cmp(group, pkey, xy, bc) == 0)
            printf("Public key %08x matches private key %08x\n",
                   *(int *)pub, *(int *)pk);
        else {
            printf(cRED "Public key mismatch!" cNORM "\n");
            exit(1);
        }
        EC_POINT_free(xy);
    }
    EC_POINT_free(pkey);
    BN_CTX_end(bc);
    BN_CTX_free(bc);

    return key;
}

int test_derive(struct test_derive *t, const char *name)
{
    int ret = 0;

    printf(cBLUE "Test %s" cNORM " for %s\n", t->descr, name);

    EVP_PKEY *keyA = load_private_key(t->key_nid, t->param_nid,
                                      t->key_a_priv, t->key_a_pub);
    EVP_PKEY *keyB = load_private_key(t->key_nid, t->param_nid,
                                      NULL, t->key_b_pub);

    EVP_PKEY_CTX *ctx;
    T(ctx = EVP_PKEY_CTX_new(keyA, NULL));
    T(EVP_PKEY_derive_init(ctx));
    T(EVP_PKEY_derive_set_peer(ctx, keyB));
    if (t->dgst_nid)
        T(EVP_PKEY_CTX_ctrl(ctx, -1, -1, EVP_PKEY_CTRL_SET_VKO,
                            t->dgst_nid, NULL));
    T(EVP_PKEY_CTX_ctrl(ctx, -1, -1, EVP_PKEY_CTRL_SET_IV,
                        t->ukm_len, (unsigned char *)t->ukm));

    size_t skeylen;
    unsigned char *skey;
    T(EVP_PKEY_derive(ctx, NULL, &skeylen));
    T(skey = OPENSSL_malloc(skeylen));

    T(EVP_PKEY_derive(ctx, skey, &skeylen));
#ifdef DEBUG
    BIO_dump_fp(stdout, skey, skeylen);
#endif

    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(keyA);
    EVP_PKEY_free(keyB);

    if (t->kek_len == skeylen && memcmp(t->kek, skey, skeylen) == 0)
        printf(cGREEN "KEK match etalon" cNORM "\n");
    else {
        printf(cRED "KEK mismatch etalon" cNORM "\n");
        ret = 1;
    }
    OPENSSL_free(skey);
    return ret;
}

int test_derive_pair(struct test_derive *t)
{
    int ret = 0;
    struct test_derive tt = *t;

    tt.key_b_priv = NULL;
    ret |= test_derive(&tt, "A");
    /* Test swapped keys. */
    tt.key_a_priv = t->key_b_priv;
    tt.key_a_pub  = t->key_b_pub;
    tt.key_b_priv = NULL;
    tt.key_b_pub  = t->key_a_pub;
    ret |= test_derive(&tt, "B");
    return ret;
}

static EVP_PKEY *keygen(const char *algo, const char *param)
{
    EVP_PKEY *key = NULL;

    EVP_PKEY *tkey = EVP_PKEY_new();
    T(EVP_PKEY_set_type_str(tkey, algo, -1));
    int pkey_id = EVP_PKEY_id(tkey);
    EVP_PKEY_free(tkey);

    EVP_PKEY_CTX *ctx;
    T((ctx = EVP_PKEY_CTX_new_id(pkey_id, NULL)));
    T(EVP_PKEY_keygen_init(ctx));
    T(EVP_PKEY_CTX_ctrl_str(ctx, "paramset", param));
    T(EVP_PKEY_keygen(ctx, &key));
    EVP_PKEY_CTX_free(ctx);
    return key;
}

unsigned char *derive(EVP_PKEY *keyA, EVP_PKEY *keyB, int dgst_nid,
                      int ukm_len, size_t *len)
{
    EVP_PKEY_CTX *ctx;
    T(ctx = EVP_PKEY_CTX_new(keyA, NULL));
    T(EVP_PKEY_derive_init(ctx));
    T(EVP_PKEY_derive_set_peer(ctx, keyB));
    if (dgst_nid)
        T(EVP_PKEY_CTX_ctrl(ctx, -1, -1, EVP_PKEY_CTRL_SET_VKO,
                            dgst_nid, NULL));
    if (ukm_len) {
        unsigned char ukm[32] = { 1 };

        OPENSSL_assert(ukm_len <= sizeof(ukm));
        T(EVP_PKEY_CTX_ctrl(ctx, -1, -1, EVP_PKEY_CTRL_SET_IV,
                            ukm_len, ukm));
    }

    T(EVP_PKEY_derive(ctx, NULL, len));
    unsigned char *skey;
    T(skey = OPENSSL_malloc(*len));

    T(EVP_PKEY_derive(ctx, skey, len));
#ifdef DEBUG
    BIO_dump_fp(stdout, skey, *len);
#endif
    EVP_PKEY_CTX_free(ctx);
    return skey;
}

int test_derive_alg(const char *algo, const char *param, int mode)
{
    int ret = 0;

    char *name = NULL;
    int dgst_nid = 0;
    int ukm_len = 0;
    switch (mode) {
    case 0:
        dgst_nid = NID_id_GostR3411_2012_256;
        name = "VKO256";
        ukm_len = 1;
        break;
    case 1:
        dgst_nid = NID_id_GostR3411_2012_512;
        name = "VKO512";
        ukm_len = 1;
        break;
    case 2:
        name = "VKO";
        ukm_len = 8;
        break;
    case 3:
        if (!strcmp(algo, "gost2001"))
            return 0; /* Skip. */
        name = "KEG";
        ukm_len = 32;
        break;
#define NR_MODES 4
    default:
        abort();
    }
    printf(cBLUE "Test %s for %s %s" cNORM " - ", name, algo, param);

    EVP_PKEY *keyA = keygen(algo, param);
    EVP_PKEY *keyB = keygen(algo, param);

    size_t skeyA_len, skeyB_len;
    unsigned char *skeyA = derive(keyA, keyB, dgst_nid, ukm_len, &skeyA_len);
    unsigned char *skeyB = derive(keyB, keyA, dgst_nid, ukm_len, &skeyB_len);

    ret = memcmp(skeyA, skeyB, skeyA_len);
    if (!ret)
        printf(cGREEN "KEK match" cNORM "\n");
    else
        printf(cRED "KEK mismatch" cNORM "\n");

    EVP_PKEY_free(keyA);
    EVP_PKEY_free(keyB);
    OPENSSL_free(skeyA);
    OPENSSL_free(skeyB);
    return ret;
}

int main(int argc, char **argv)
{
    int ret = 0;

    OPENSSL_add_all_algorithms_conf();

    int i;
    for (i = 0; i < OSSL_NELEM(derive_tests); i++)
        ret |= test_derive_pair(&derive_tests[i]);

    for (i = 0; i < NR_MODES; i++) {
        ret |= test_derive_alg("gost2001", "A", i);
        ret |= test_derive_alg("gost2001", "B", i);
        ret |= test_derive_alg("gost2001", "C", i);
        ret |= test_derive_alg("gost2012_256", "A", i);
        ret |= test_derive_alg("gost2012_256", "B", i);
        ret |= test_derive_alg("gost2012_256", "C", i);
        ret |= test_derive_alg("gost2012_256", "TCA", i);
        ret |= test_derive_alg("gost2012_512", "A", i);
        ret |= test_derive_alg("gost2012_512", "B", i);
        ret |= test_derive_alg("gost2012_512", "C", i);
    }

    if (ret)
        printf(cDRED "= Some tests FAILED!" cNORM "\n");
    else
        printf(cDGREEN "= All tests passed!" cNORM "\n");
    return ret;
}
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
