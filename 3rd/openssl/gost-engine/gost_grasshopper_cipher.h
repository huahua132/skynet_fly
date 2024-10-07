/*
 * Maxim Tishkov 2016
 * This file is distributed under the same license as OpenSSL
 */

#ifndef GOST_GRASSHOPPER_CIPHER_H
#define GOST_GRASSHOPPER_CIPHER_H

#define SN_kuznyechik_mgm      "kuznyechik-mgm"

#if defined(__cplusplus)
extern "C" {
#endif

#include "gost_grasshopper_defines.h"

#include "gost_lcl.h"
#include <openssl/evp.h>

// not thread safe
// because of buffers
typedef struct {
    uint8_t type;
    grasshopper_key_t master_key;
    grasshopper_key_t key;
    grasshopper_round_keys_t encrypt_round_keys;
    grasshopper_round_keys_t decrypt_round_keys;
    grasshopper_w128_t buffer;
} gost_grasshopper_cipher_ctx;

typedef struct {
    gost_grasshopper_cipher_ctx c;
    grasshopper_w128_t partial_buffer;
    unsigned int section_size;  /* After how much bytes mesh the key,
				   if 0 never mesh and work like plain ctr. */
    unsigned char kdf_seed[8];
		unsigned char tag[16];
		EVP_MD_CTX *omac_ctx;
} gost_grasshopper_cipher_ctx_ctr;

static void gost_grasshopper_cipher_key(gost_grasshopper_cipher_ctx* c, const uint8_t* k);

static void gost_grasshopper_cipher_destroy(gost_grasshopper_cipher_ctx* c);

static int gost_grasshopper_cipher_init_ecb(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_cbc(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_ofb(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_cfb(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_ctr(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_ctracpkm(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_ctracpkm_omac(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init_mgm(EVP_CIPHER_CTX* ctx,
    const unsigned char* key, const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_init(EVP_CIPHER_CTX* ctx, const unsigned char* key,
    const unsigned char* iv, int enc);

static int gost_grasshopper_cipher_do(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_ecb(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_cbc(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_ofb(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_cfb(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_ctr(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_ctracpkm(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_ctracpkm_omac(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_do_mgm(EVP_CIPHER_CTX* ctx, unsigned char* out,
    const unsigned char* in, size_t inl);

static int gost_grasshopper_cipher_cleanup(EVP_CIPHER_CTX* ctx);

static int gost_grasshopper_mgm_cleanup(EVP_CIPHER_CTX *c);

static int gost_grasshopper_set_asn1_parameters(EVP_CIPHER_CTX* ctx, ASN1_TYPE* params);

static int gost_grasshopper_get_asn1_parameters(EVP_CIPHER_CTX* ctx, ASN1_TYPE* params);

static int gost_grasshopper_cipher_ctl(EVP_CIPHER_CTX* ctx, int type, int arg, void* ptr);

static int gost_grasshopper_mgm_ctrl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr);

const EVP_CIPHER* cipher_gost_grasshopper_ctracpkm();

#if defined(__cplusplus)
}
#endif

#endif
