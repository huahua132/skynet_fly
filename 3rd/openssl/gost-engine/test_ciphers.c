/*
 * Copyright (C) 2018,2020 Vitaly Chikunov <vt@altlinux.org>. All Rights Reserved.
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
#include <openssl/provider.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#include <string.h>

#if defined _MSC_VER
# include <malloc.h>
# define alloca _alloca
#elif defined __linux__
# include <alloca.h>
#endif
#include <stdlib.h>

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
#define cMAGENT "\033[1;35m"
#define cDBLUE	"\033[0;34m"
#define cNORM	"\033[m"
#define TEST_ASSERT(e) {if ((test = (e))) \
		 printf(cRED "Test FAILED" cNORM "\n"); \
	     else \
		 printf(cGREEN "Test passed" cNORM "\n");}

#ifdef __GNUC__
/* Pragma to allow commenting out some tests. */
# pragma GCC diagnostic ignored "-Wunused-const-variable"
#endif

/*
 * Test keys from both GOST R 34.12-2015 and GOST R 34.13-2015,
 * for 128-bit cipher (A.1).
 */
static const unsigned char K[32] = {
    0x88,0x99,0xaa,0xbb,0xcc,0xdd,0xee,0xff,0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,
    0xfe,0xdc,0xba,0x98,0x76,0x54,0x32,0x10,0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef,
};

/*
 * Key for 64-bit cipher (A.2).
 */
static const unsigned char Km[32] = {
    0xff,0xee,0xdd,0xcc,0xbb,0xaa,0x99,0x88,0x77,0x66,0x55,0x44,0x33,0x22,0x11,0x00,
    0xf0,0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff,
};

/*
 * Plaintext from GOST R 34.13-2015 A.1.
 * First 16 bytes is vector (a) from GOST R 34.12-2015 A.1.
 */
static const unsigned char P[] = {
    0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x00,0xff,0xee,0xdd,0xcc,0xbb,0xaa,0x99,0x88,
    0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xaa,0xbb,0xcc,0xee,0xff,0x0a,
    0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xaa,0xbb,0xcc,0xee,0xff,0x0a,0x00,
    0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xaa,0xbb,0xcc,0xee,0xff,0x0a,0x00,0x11,
};

/* Plaintext for 64-bit cipher (A.2) */
static const unsigned char Pm[] = {
    0x92,0xde,0xf0,0x6b,0x3c,0x13,0x0a,0x59,0xdb,0x54,0xc7,0x04,0xf8,0x18,0x9d,0x20,
    0x4a,0x98,0xfb,0x2e,0x67,0xa8,0x02,0x4c,0x89,0x12,0x40,0x9b,0x17,0xb5,0x7e,0x41,
};

/* Extended plaintext from tc26 acpkm Kuznyechik test vector */
static const unsigned char P_acpkm[] = {
    0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x00,0xFF,0xEE,0xDD,0xCC,0xBB,0xAA,0x99,0x88,
    0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xEE,0xFF,0x0A,
    0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xEE,0xFF,0x0A,0x00,
    0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xEE,0xFF,0x0A,0x00,0x11,
    0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xEE,0xFF,0x0A,0x00,0x11,0x22,
    0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xEE,0xFF,0x0A,0x00,0x11,0x22,0x33,
    0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xEE,0xFF,0x0A,0x00,0x11,0x22,0x33,0x44,
};
static const unsigned char E_ecb[] = {
    /* ECB test vectors from GOST R 34.13-2015  A.1.1 */
    /* first 16 bytes is vector (b) from GOST R 34.12-2015 A.1 */
    0x7f,0x67,0x9d,0x90,0xbe,0xbc,0x24,0x30,0x5a,0x46,0x8d,0x42,0xb9,0xd4,0xed,0xcd,
    0xb4,0x29,0x91,0x2c,0x6e,0x00,0x32,0xf9,0x28,0x54,0x52,0xd7,0x67,0x18,0xd0,0x8b,
    0xf0,0xca,0x33,0x54,0x9d,0x24,0x7c,0xee,0xf3,0xf5,0xa5,0x31,0x3b,0xd4,0xb1,0x57,
    0xd0,0xb0,0x9c,0xcd,0xe8,0x30,0xb9,0xeb,0x3a,0x02,0xc4,0xc5,0xaa,0x8a,0xda,0x98,
};
static const unsigned char E_ctr[] = {
    /* CTR test vectors from GOST R 34.13-2015  A.1.2 */
    0xf1,0x95,0xd8,0xbe,0xc1,0x0e,0xd1,0xdb,0xd5,0x7b,0x5f,0xa2,0x40,0xbd,0xa1,0xb8,
    0x85,0xee,0xe7,0x33,0xf6,0xa1,0x3e,0x5d,0xf3,0x3c,0xe4,0xb3,0x3c,0x45,0xde,0xe4,
    0xa5,0xea,0xe8,0x8b,0xe6,0x35,0x6e,0xd3,0xd5,0xe8,0x77,0xf1,0x35,0x64,0xa3,0xa5,
    0xcb,0x91,0xfa,0xb1,0xf2,0x0c,0xba,0xb6,0xd1,0xc6,0xd1,0x58,0x20,0xbd,0xba,0x73,
};
static const unsigned char Em_ctr[] = {
    /* CTR test vectors from GOST R 34.13-2015  A.2.2 */
    0x4e,0x98,0x11,0x0c,0x97,0xb7,0xb9,0x3c,0x3e,0x25,0x0d,0x93,0xd6,0xe8,0x5d,0x69,
    0x13,0x6d,0x86,0x88,0x07,0xb2,0xdb,0xef,0x56,0x8e,0xb6,0x80,0xab,0x52,0xa1,0x2d,
};
static const unsigned char E_acpkm[] = {
    0xF1,0x95,0xD8,0xBE,0xC1,0x0E,0xD1,0xDB,0xD5,0x7B,0x5F,0xA2,0x40,0xBD,0xA1,0xB8,
    0x85,0xEE,0xE7,0x33,0xF6,0xA1,0x3E,0x5D,0xF3,0x3C,0xE4,0xB3,0x3C,0x45,0xDE,0xE4,
    0x4B,0xCE,0xEB,0x8F,0x64,0x6F,0x4C,0x55,0x00,0x17,0x06,0x27,0x5E,0x85,0xE8,0x00,
    0x58,0x7C,0x4D,0xF5,0x68,0xD0,0x94,0x39,0x3E,0x48,0x34,0xAF,0xD0,0x80,0x50,0x46,
    0xCF,0x30,0xF5,0x76,0x86,0xAE,0xEC,0xE1,0x1C,0xFC,0x6C,0x31,0x6B,0x8A,0x89,0x6E,
    0xDF,0xFD,0x07,0xEC,0x81,0x36,0x36,0x46,0x0C,0x4F,0x3B,0x74,0x34,0x23,0x16,0x3E,
    0x64,0x09,0xA9,0xC2,0x82,0xFA,0xC8,0xD4,0x69,0xD2,0x21,0xE7,0xFB,0xD6,0xDE,0x5D,
};
/* Test vector from R 23565.1.017-2018 A.4.2.
 * Key material from ACPKM-Master(K,768,3) for OMAC-ACPKM. */
static const unsigned char E_acpkm_master[] = {
    0x0C,0xAB,0xF1,0xF2,0xEF,0xBC,0x4A,0xC1,0x60,0x48,0xDF,0x1A,0x24,0xC6,0x05,0xB2,
    0xC0,0xD1,0x67,0x3D,0x75,0x86,0xA8,0xEC,0x0D,0xD4,0x2C,0x45,0xA4,0xF9,0x5B,0xAE,
    0x0F,0x2E,0x26,0x17,0xE4,0x71,0x48,0x68,0x0F,0xC3,0xE6,0x17,0x8D,0xF2,0xC1,0x37,
    0xC9,0xDD,0xA8,0x9C,0xFF,0xA4,0x91,0xFE,0xAD,0xD9,0xB3,0xEA,0xB7,0x03,0xBB,0x31,
    0xBC,0x7E,0x92,0x7F,0x04,0x94,0x72,0x9F,0x51,0xB4,0x9D,0x3D,0xF9,0xC9,0x46,0x08,
    0x00,0xFB,0xBC,0xF5,0xED,0xEE,0x61,0x0E,0xA0,0x2F,0x01,0x09,0x3C,0x7B,0xC7,0x42,
    0xD7,0xD6,0x27,0x15,0x01,0xB1,0x77,0x77,0x52,0x63,0xC2,0xA3,0x49,0x5A,0x83,0x18,
    0xA8,0x1C,0x79,0xA0,0x4F,0x29,0x66,0x0E,0xA3,0xFD,0xA8,0x74,0xC6,0x30,0x79,0x9E,
    0x14,0x2C,0x57,0x79,0x14,0xFE,0xA9,0x0D,0x3B,0xC2,0x50,0x2E,0x83,0x36,0x85,0xD9,
};
static const unsigned char P_acpkm_master[sizeof(E_acpkm_master)] = { 0 };
/*
 * Other modes (ofb, cbc, cfb) is impossible to test to match GOST R
 * 34.13-2015 test vectors exactly, due to these vectors having exceeding
 * IV length value (m) = 256 bits, while openssl have hard-coded limit
 * of maximum IV length of 128 bits (EVP_MAX_IV_LENGTH).
 * Also, current grasshopper code having fixed IV length of 128 bits.
 *
 * Thus, new test vectors are generated with truncated 128-bit IV using
 * canonical GOST implementation from TC26.
 */
static const unsigned char E_ofb[] = {
    /* OFB test vector generated from canonical implementation */
    0x81,0x80,0x0a,0x59,0xb1,0x84,0x2b,0x24,0xff,0x1f,0x79,0x5e,0x89,0x7a,0xbd,0x95,
    0x77,0x91,0x46,0xdb,0x2d,0x93,0xa9,0x4e,0xd9,0x3c,0xf6,0x8b,0x32,0x39,0x7f,0x19,
    0xe9,0x3c,0x9e,0x57,0x44,0x1d,0x87,0x05,0x45,0xf2,0x40,0x36,0xa5,0x8c,0xee,0xa3,
    0xcf,0x3f,0x00,0x61,0xd5,0x64,0x23,0x54,0x5b,0x96,0x0d,0x86,0x4c,0xc8,0x68,0xda,
};
static const unsigned char E_cbc[] = {
    /* CBC test vector generated from canonical implementation */
    0x68,0x99,0x72,0xd4,0xa0,0x85,0xfa,0x4d,0x90,0xe5,0x2e,0x3d,0x6d,0x7d,0xcc,0x27,
    0xab,0xf1,0x70,0xb2,0xb2,0x26,0xc3,0x01,0x0c,0xcf,0xa1,0x36,0xd6,0x59,0xcd,0xaa,
    0xca,0x71,0x92,0x72,0xab,0x1d,0x43,0x8e,0x15,0x50,0x7d,0x52,0x1e,0xcd,0x55,0x22,
    0xe0,0x11,0x08,0xff,0x8d,0x9d,0x3a,0x6d,0x8c,0xa2,0xa5,0x33,0xfa,0x61,0x4e,0x71,
};
static const unsigned char E_cfb[] = {
    /* CFB test vector generated from canonical implementation */
    0x81,0x80,0x0a,0x59,0xb1,0x84,0x2b,0x24,0xff,0x1f,0x79,0x5e,0x89,0x7a,0xbd,0x95,
    0x68,0xc1,0xb9,0x9c,0x4d,0xf5,0x9c,0xc7,0x95,0x1e,0x37,0x39,0xb5,0xb3,0xcd,0xbf,
    0x07,0x3f,0x4d,0xd2,0xd6,0xde,0xb3,0xcf,0xb0,0x26,0x54,0x5f,0x7a,0xf1,0xd8,0xe8,
    0xe1,0xc8,0x52,0xe9,0xa8,0x56,0x71,0x62,0xdb,0xb5,0xda,0x7f,0x66,0xde,0xa9,0x26,
};
static const unsigned char Em_cbc[] = {
    /* 28147-89 CBC test vector generated from canonical implementation */
    0x96,0xd1,0xb0,0x5e,0xea,0x68,0x39,0x19,0xf3,0x96,0xb7,0x8c,0x1d,0x47,0xbb,0x61,
    0x61,0x83,0xe2,0xcc,0xa9,0x76,0xa4,0xba,0xbe,0x9c,0xe8,0x7d,0x6f,0xa7,0x3c,0xf2,
};

/* IV is half CNT size. */
static const unsigned char iv_ctr[]	= { 0x12,0x34,0x56,0x78,0x90,0xab,0xce,0xf0 };
/* Third of IV from GOST R 34.13-2015 А.2.4 (Impossible to use full 192-bit IV.) */
static const unsigned char iv_cbc[]	= { 0x12,0x34,0x56,0x78,0x90,0xab,0xcd,0xef };
/* Truncated to 128-bits IV from GOST examples. */
static const unsigned char iv_128bit[]	= { 0x12,0x34,0x56,0x78,0x90,0xab,0xce,0xf0,
					    0xa1,0xb2,0xc3,0xd4,0xe5,0xf0,0x01,0x12 };
/* Universal IV for ACPKM-Master. */
static const unsigned char iv_acpkm_m[]	= { 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff };

static struct testcase {
    const char *algname;
    int block; /* Actual underlying block size (bytes). */
    int stream; /* Stream cipher. */
    const unsigned char *plaintext;
    const unsigned char *key;
    const unsigned char *expected;
    size_t size;
    const unsigned char *iv;
    size_t iv_size;
    int acpkm;
} testcases[] = {
    {
	.algname = SN_grasshopper_ecb,
	.block = 16,
	.plaintext = P,
	.key = K,
	.expected = E_ecb,
	.size = sizeof(P),
    },
    {
	.algname = SN_grasshopper_ctr,
	.block = 16,
	.stream = 1,
	.plaintext = P,
	.key = K,
	.expected = E_ctr,
	.size = sizeof(P),
	.iv = iv_ctr,
	.iv_size = sizeof(iv_ctr),
    },
    {
	.algname = SN_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm,
	.block = 16,
	.stream = 1,
	.plaintext = P,
	.key = K,
	.expected = E_ctr,
	.size = sizeof(P),
	.iv = iv_ctr,
	.iv_size = sizeof(iv_ctr),
	/* no acpkm works same as ctr */
    },
    {
	.algname = SN_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm,
	.block = 16,
	.stream = 1,
	.plaintext = P_acpkm,
	.key = K,
	.expected = E_acpkm,
	.size = sizeof(P_acpkm),
	.iv = iv_ctr,
	.iv_size = sizeof(iv_ctr),
	.acpkm = 256 / 8,
    },
    {
	.algname = SN_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm,
	.block = 16,
	.plaintext = P_acpkm_master,
	.key = K,
	.expected = E_acpkm_master,
	.size = sizeof(P_acpkm_master),
	.iv = iv_acpkm_m,
	.iv_size = sizeof(iv_acpkm_m),
	.acpkm = 768 / 8
    },
    {
	.algname = SN_grasshopper_ofb,
	.block = 16,
	.stream = 1,
	.plaintext = P,
	.key = K,
	.expected = E_ofb,
	.size = sizeof(P),
	.iv = iv_128bit,
	.iv_size = sizeof(iv_128bit),
    },
    {
	.algname = SN_grasshopper_cbc,
	.block = 16,
	.plaintext = P,
	.key = K,
	.expected = E_cbc,
	.size = sizeof(P),
	.iv = iv_128bit,
	.iv_size = sizeof(iv_128bit),
    },
    {
	.algname = SN_grasshopper_cfb,
	.block = 16,
	.plaintext = P,
	.key = K,
	.expected = E_cfb,
	.size = sizeof(P),
	.iv = iv_128bit,
	.iv_size = sizeof(iv_128bit),
    },
    {
	.algname = SN_magma_ctr,
	.block = 8,
	.plaintext = Pm,
	.key = Km,
	.expected = Em_ctr,
	.size = sizeof(Pm),
	.iv = iv_ctr,
	.iv_size = sizeof(iv_ctr) / 2,
    },
    {
	.algname = SN_magma_cbc,
	.block = 8,
	.plaintext = Pm,
	.key = Km,
	.expected = Em_cbc,
	.size = sizeof(Pm),
	.iv = iv_cbc,
	.iv_size = sizeof(iv_cbc),
    },
    { 0 }
};

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

static int test_block(const EVP_CIPHER *type, const char *name, int block_size,
    const unsigned char *pt, const unsigned char *key, const unsigned char *exp,
    const size_t size, const unsigned char *iv, size_t iv_size, int acpkm,
    int inplace)
{
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    const char *standard = acpkm? "R 23565.1.017-2018" : "GOST R 34.13-2015";
    unsigned char *c = alloca(size);
    int outlen, tmplen;
    int ret = 0, test;

    OPENSSL_assert(ctx);
    printf("Encryption test from %s [%s] %s: ", standard, name,
	inplace ? "in-place" : "out-of-place");

    T(EVP_CIPHER_iv_length(type) == iv_size);

    if (EVP_CIPHER_block_size(type) == 1) {
	/* Cannot test block size, but can report it's stream cipher. */
	printf("stream: ");
    } else
	T(EVP_CIPHER_block_size(type) == block_size);

    /* test with single big chunk */
    EVP_CIPHER_CTX_init(ctx);
    T(EVP_CipherInit_ex(ctx, type, NULL, key, iv, 1));
    T(EVP_CIPHER_CTX_set_padding(ctx, 0));
    if (inplace)
	memcpy(c, pt, size);
    else
	memset(c, 0, size);
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
    T(EVP_CipherUpdate(ctx, c, &outlen, inplace? c : pt, size));
    T(EVP_CipherFinal_ex(ctx, c + outlen, &tmplen));
    EVP_CIPHER_CTX_cleanup(ctx);

    TEST_ASSERT(outlen != size || memcmp(c, exp, size));
    if (test) {
	printf("  c[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    /* test with small chunks of block size */
    printf("Chunked encryption test from %s [%s] %s: ", standard, name,
	inplace ? "in-place" : "out-of-place");
    int blocks = size / block_size;
    int z;
    EVP_CIPHER_CTX_init(ctx);
    T(EVP_CipherInit_ex(ctx, type, NULL, key, iv, 1));
    T(EVP_CIPHER_CTX_set_padding(ctx, 0));
    if (inplace)
	memcpy(c, pt, size);
    else
	memset(c, 0, size);
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
    for (z = 0; z < blocks; z++) {
	int offset = z * block_size;
	int sz = block_size;

	T(EVP_CipherUpdate(ctx, c + offset, &outlen, (inplace ? c : pt) + offset, sz));
    }
    outlen = z * block_size;
    T(EVP_CipherFinal_ex(ctx, c + outlen, &tmplen));
    EVP_CIPHER_CTX_cleanup(ctx);

    TEST_ASSERT(outlen != size || memcmp(c, exp, size));
    if (test) {
	printf("  c[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    /* test with single big chunk */
    printf("Decryption test from %s [%s] %s: ", standard, name,
	inplace ? "in-place" : "out-of-place");
    EVP_CIPHER_CTX_init(ctx);
    T(EVP_CipherInit_ex(ctx, type, NULL, key, iv, 0));
    T(EVP_CIPHER_CTX_set_padding(ctx, 0));
    if (inplace)
	memcpy(c, exp, size);
    else
	memset(c, 0, size);
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
    T(EVP_CipherUpdate(ctx, c, &outlen, inplace ? c : exp, size));
    T(EVP_CipherFinal_ex(ctx, c + outlen, &tmplen));
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);

    TEST_ASSERT(outlen != size || memcmp(c, pt, size));
    if (test) {
	printf("  d[%d] = ", outlen);
	hexdump(c, outlen);
    }
    ret |= test;

    return ret;
}

static int test_stream(const EVP_CIPHER *type, const char *name,
    const unsigned char *pt, const unsigned char *key, const unsigned char *exp,
    const size_t size, const unsigned char *iv, size_t iv_size, int acpkm)
{
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    const char *standard = acpkm? "R 23565.1.017-2018" : "GOST R 34.13-2015";
    unsigned char *c = alloca(size);
    int ret = 0, test;
    int z;

    OPENSSL_assert(ctx);
    /* Cycle through all lengths from 1 upto maximum size */
    printf("Stream encryption test from %s [%s] \n", standard, name);

    /* Block size for stream ciphers should be 1. */
    T(EVP_CIPHER_block_size(type) == 1);

    for (z = 1; z <= size; z++) {
	int outlen, tmplen;
	int sz = 0;
	int i;

	EVP_CIPHER_CTX_init(ctx);
	T(EVP_CipherInit_ex(ctx, type, NULL, key, iv, 1));
	T(EVP_CIPHER_CTX_set_padding(ctx, 0));
	memset(c, 0xff, size);
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
	for (i = 0; i < size; i += z) {
	    if (i + z > size)
		sz = size - i;
	    else
		sz = z;
	    T(EVP_CipherUpdate(ctx, c + i, &outlen, pt + i, sz));
	    OPENSSL_assert(outlen == sz);
	}
	outlen = i - z + sz;
	T(EVP_CipherFinal_ex(ctx, c + outlen, &tmplen));
	EVP_CIPHER_CTX_cleanup(ctx);

	test = outlen != size || memcmp(c, exp, size);
	printf("%c", test ? 'E' : '+');
	ret |= test;
    }
    printf("\n");
    TEST_ASSERT(ret);
    EVP_CIPHER_CTX_free(ctx);

    return ret;
}

int engine_is_available(const char *name)
{
    ENGINE *e = ENGINE_get_first();

    while (e != NULL) {
        if (strcmp(ENGINE_get_id(e), name) == 0)
            break;
        e = ENGINE_get_next(e);
    }
    ENGINE_free(e);
    return 0;
}

void warn_if_untested(const EVP_CIPHER *ciph, void *provider)
{
    const struct testcase *t;

    /* ENGINE provided EVP_MDs have a NULL provider */
    if (provider != EVP_CIPHER_get0_provider(ciph))
        return;

    for (t = testcases; t->algname; t++)
        if (EVP_CIPHER_is_a(ciph, t->algname))
            break;
    if (!t->algname)
        printf(cMAGENT "Cipher %s is untested!" cNORM "\n", EVP_CIPHER_name(ciph));
}

void warn_all_untested(void)
{
    if (engine_is_available("gost")) {
        ENGINE *eng;

        T(eng = ENGINE_by_id("gost"));
        T(ENGINE_init(eng));

        ENGINE_CIPHERS_PTR fn_c;
        T(fn_c = ENGINE_get_ciphers(eng));
        const int *nids;
        int n, k;
        n = fn_c(eng, NULL, &nids, 0);
        for (k = 0; k < n; ++k)
            warn_if_untested(ENGINE_get_cipher(eng, nids[k]), NULL);
        ENGINE_finish(eng);
        ENGINE_free(eng);
    }
    if (OSSL_PROVIDER_available(NULL, "gostprov")) {
        OSSL_PROVIDER *prov;

        T(prov = OSSL_PROVIDER_load(NULL, "gostprov"));
        EVP_CIPHER_do_all_provided(NULL,
                                   (void (*)(EVP_CIPHER *, void *))warn_if_untested,
                                   prov);

        OSSL_PROVIDER_unload(prov);
    }
}

int main(int argc, char **argv)
{
    int ret = 0;
    const struct testcase *t;

#if MIPSEL
    /* Trigger SIGBUS for unaligned access. */
    sysmips(MIPS_FIXADE, 0);
#endif
    OPENSSL_add_all_algorithms_conf();

    for (t = testcases; t->algname; t++) {
	int inplace;
	const char *standard = t->acpkm? "R 23565.1.017-2018" : "GOST R 34.13-2015";

	EVP_CIPHER *ciph;

	ERR_set_mark();
	T((ciph = (EVP_CIPHER *)EVP_get_cipherbyname(t->algname))
	  || (ciph = EVP_CIPHER_fetch(NULL, t->algname, NULL)));
	ERR_pop_to_mark();

	printf(cBLUE "# Tests for %s [%s]" cNORM "\n", t->algname, standard);
	for (inplace = 0; inplace <= 1; inplace++)
	    ret |= test_block(ciph, t->algname, t->block,
		t->plaintext, t->key, t->expected, t->size,
		t->iv, t->iv_size, t->acpkm, inplace);
	if (t->stream)
	    ret |= test_stream(ciph, t->algname,
		t->plaintext, t->key, t->expected, t->size,
		t->iv, t->iv_size, t->acpkm);

	EVP_CIPHER_free(ciph);
    }

    warn_all_untested();

    if (ret)
	printf(cDRED "= Some tests FAILED!" cNORM "\n");
    else
	printf(cDGREEN "= All tests passed!" cNORM "\n");
    return ret;
}
