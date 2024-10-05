/*
 * Copyright (c) 2020 Dmitry Belyavskiy <beldmit@gmail.com>
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */
#ifndef GOST_GOST2015_H
#define GOST_GOST2015_H

#include "gost_grasshopper_cipher.h"

#include <openssl/evp.h>
#include <openssl/x509.h>
#include <openssl/modes.h>

#define MAGMA_MAC_MAX_SIZE 8
#define KUZNYECHIK_MAC_MAX_SIZE 16
#define OID_GOST_CMS_MAC "1.2.643.7.1.0.6.1.1"

#define SN_magma_mgm            "magma-mgm"

#define BSWAP64(x) \
    (((x & 0xFF00000000000000ULL) >> 56) | \
     ((x & 0x00FF000000000000ULL) >> 40) | \
     ((x & 0x0000FF0000000000ULL) >> 24) | \
     ((x & 0x000000FF00000000ULL) >>  8) | \
     ((x & 0x00000000FF000000ULL) <<  8) | \
     ((x & 0x0000000000FF0000ULL) << 24) | \
     ((x & 0x000000000000FF00ULL) << 40) | \
     ((x & 0x00000000000000FFULL) << 56))

typedef void (*mul128_f) (uint64_t *result, uint64_t *arg1, uint64_t *arg2);

typedef struct {
    union {
        uint64_t u[2];
        uint32_t d[4];
        uint8_t c[16];
    } nonce, Yi, Zi, EKi, Hi, len, ACi, mul, sum, tag;

    unsigned int mres, ares;
    block128_f block;
    mul128_f mul_gf;
    int blocklen;
    void *key;
} mgm128_context;

typedef struct {
    union {
        struct ossl_gost_cipher_ctx g_ks;
        gost_grasshopper_cipher_ctx gh_ks;
    } ks;
    int key_set;
    int iv_set;
    mgm128_context mgm;
    unsigned char *iv;
    int ivlen;
    int taglen;
    int tlstree_mode;
} gost_mgm_ctx;

int gost2015_final_call(EVP_CIPHER_CTX *ctx, EVP_MD_CTX *omac_ctx, size_t mac_size,
			unsigned char *encrypted_mac,
			int (*do_cipher) (EVP_CIPHER_CTX *ctx,
				unsigned char *out,
				const unsigned char *in,
				size_t inl));

/* IV is expected to be 16 bytes*/
int gost2015_get_asn1_params(const ASN1_TYPE *params, size_t ukm_size,
	unsigned char *iv, size_t ukm_offset, unsigned char *kdf_seed);

int gost2015_set_asn1_params(ASN1_TYPE *params,
	const unsigned char *iv, size_t iv_size, const unsigned char *kdf_seed);

int gost2015_process_unprotected_attributes(STACK_OF(X509_ATTRIBUTE) *attrs,
            int encryption, size_t mac_len, unsigned char *final_tag);

int gost2015_acpkm_omac_init(int nid, int enc, const unsigned char *inkey,
                             EVP_MD_CTX *omac_ctx,
                             unsigned char *outkey, unsigned char *kdf_seed);
int init_zero_kdf_seed(unsigned char *kdf_seed);


/* enc/dec mgm mode */

void gost_mgm128_init(mgm128_context *ctx, void *key, block128_f block,
					  mul128_f mul_gf, int blen);

int gost_mgm128_setiv(mgm128_context *ctx, const unsigned char *iv, size_t len);

int gost_mgm128_aad(mgm128_context *ctx, const unsigned char *aad, size_t len);

int gost_mgm128_encrypt(mgm128_context *ctx, const unsigned char *in,
                          unsigned char *out, size_t len);

int gost_mgm128_decrypt(mgm128_context *ctx, const unsigned char *in,
                          unsigned char *out, size_t len);

int gost_mgm128_finish(mgm128_context *ctx, const unsigned char *tag, size_t len);

void gost_mgm128_tag(mgm128_context *ctx, unsigned char *tag, size_t len);

#endif
