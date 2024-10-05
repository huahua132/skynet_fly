/*
 * Copyright (c) 2019 Dmitry Belyavskiy <beldmit@gmail.com>
 * Copyright (c) 2020 Vitaly Chikunov <vt@altlinux.org>
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#include <string.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/buffer.h>

#include "gost_lcl.h"
#include "e_gost_err.h"

static uint32_t be32(uint32_t host)
{
#ifdef L_ENDIAN
    return (host & 0xff000000) >> 24 |
           (host & 0x00ff0000) >> 8  |
           (host & 0x0000ff00) << 8  |
           (host & 0x000000ff) << 24;
#else
    return host;
#endif
}

int omac_imit_ctrl(EVP_MD_CTX *ctx, int type, int arg, void *ptr);
/*
 * Function expects that out is a preallocated buffer of length
 * defined as sum of shared_len and mac length defined by mac_nid
 * */
int gost_kexp15(const unsigned char *shared_key, const int shared_len,
                int cipher_nid, const unsigned char *cipher_key,
                int mac_nid, unsigned char *mac_key,
                const unsigned char *iv, const size_t ivlen,
                unsigned char *out, int *out_len)
{
    unsigned char iv_full[16], mac_buf[16];
    unsigned int mac_len;

    EVP_CIPHER_CTX *ciph = NULL;
    EVP_MD_CTX *mac = NULL;

    int ret = 0;
    int len;

    mac_len = (cipher_nid == NID_magma_ctr) ? 8 :
        (cipher_nid == NID_grasshopper_ctr) ? 16 : 0;

    if (mac_len == 0) {
        GOSTerr(GOST_F_GOST_KEXP15, GOST_R_INVALID_CIPHER);
        goto err;
    }

    if (shared_len + mac_len > (unsigned int)(*out_len)) {
        GOSTerr(GOST_F_GOST_KEXP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }

    /* we expect IV of half length */
    memset(iv_full, 0, 16);
    memcpy(iv_full, iv, ivlen);

    mac = EVP_MD_CTX_new();
    if (mac == NULL) {
        GOSTerr(GOST_F_GOST_KEXP15, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (EVP_DigestInit_ex(mac, EVP_get_digestbynid(mac_nid), NULL) <= 0
        || omac_imit_ctrl(mac, EVP_MD_CTRL_SET_KEY, 32, mac_key) <= 0
        || omac_imit_ctrl(mac, EVP_MD_CTRL_XOF_LEN, mac_len, NULL) <= 0
        || EVP_DigestUpdate(mac, iv, ivlen) <= 0
        || EVP_DigestUpdate(mac, shared_key, shared_len) <= 0
        /* As we set MAC length directly, we should not allow overwriting it */
        || EVP_DigestFinalXOF(mac, mac_buf, mac_len) <= 0) {
        GOSTerr(GOST_F_GOST_KEXP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }

    ciph = EVP_CIPHER_CTX_new();
    if (ciph == NULL) {
        GOSTerr(GOST_F_GOST_KEXP15, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (EVP_CipherInit_ex
        (ciph, EVP_get_cipherbynid(cipher_nid), NULL, NULL, NULL, 1) <= 0
        || EVP_CipherInit_ex(ciph, NULL, NULL, cipher_key, iv_full, 1) <= 0
        || EVP_CipherUpdate(ciph, out, &len, shared_key, shared_len) <= 0
        || EVP_CipherUpdate(ciph, out + shared_len, &len, mac_buf, mac_len) <= 0
        || EVP_CipherFinal_ex(ciph, out + shared_len + len, out_len) <= 0) {
        GOSTerr(GOST_F_GOST_KEXP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }

    *out_len = shared_len + mac_len;

    ret = 1;

 err:
    OPENSSL_cleanse(mac_buf, mac_len);
    EVP_MD_CTX_free(mac);
    EVP_CIPHER_CTX_free(ciph);

    return ret;
}

/*
 * Function expects that shared_key is a preallocated buffer
 * with length defined as expkeylen + mac_len defined by mac_nid
 * */
int gost_kimp15(const unsigned char *expkey, const size_t expkeylen,
                int cipher_nid, const unsigned char *cipher_key,
                int mac_nid, unsigned char *mac_key,
                const unsigned char *iv, const size_t ivlen,
                unsigned char *shared_key)
{
    unsigned char iv_full[16], out[48], mac_buf[16];
    unsigned int mac_len;
    const size_t shared_len = 32;

    EVP_CIPHER_CTX *ciph = NULL;
    EVP_MD_CTX *mac = NULL;

    int ret = 0;
    int len;

    mac_len = (cipher_nid == NID_magma_ctr) ? 8 :
        (cipher_nid == NID_grasshopper_ctr) ? 16 : 0;

    if (mac_len == 0) {
        GOSTerr(GOST_F_GOST_KIMP15, GOST_R_INVALID_CIPHER);
        goto err;
    }

    if (expkeylen > sizeof(out)) {
        GOSTerr(GOST_F_GOST_KIMP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }

    if (ivlen > 16) {
        GOSTerr(GOST_F_GOST_KIMP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }

    /* we expect IV of half length */
    memset(iv_full, 0, 16);
    memcpy(iv_full, iv, ivlen);

    ciph = EVP_CIPHER_CTX_new();
    if (ciph == NULL) {
        GOSTerr(GOST_F_GOST_KIMP15, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (EVP_CipherInit_ex
        (ciph, EVP_get_cipherbynid(cipher_nid), NULL, NULL, NULL, 0) <= 0
        || EVP_CipherInit_ex(ciph, NULL, NULL, cipher_key, iv_full, 0) <= 0
        || EVP_CipherUpdate(ciph, out, &len, expkey, expkeylen) <= 0
        || EVP_CipherFinal_ex(ciph, out + len, &len) <= 0) {
        GOSTerr(GOST_F_GOST_KIMP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }
    /*Now we have shared key and mac in out[] */

    mac = EVP_MD_CTX_new();
    if (mac == NULL) {
        GOSTerr(GOST_F_GOST_KIMP15, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (EVP_DigestInit_ex(mac, EVP_get_digestbynid(mac_nid), NULL) <= 0
        || omac_imit_ctrl(mac, EVP_MD_CTRL_SET_KEY, 32, mac_key) <= 0
        || omac_imit_ctrl(mac, EVP_MD_CTRL_XOF_LEN, mac_len, NULL) <= 0
        || EVP_DigestUpdate(mac, iv, ivlen) <= 0
        || EVP_DigestUpdate(mac, out, shared_len) <= 0
        /* As we set MAC length directly, we should not allow overwriting it */
        || EVP_DigestFinalXOF(mac, mac_buf, mac_len) <= 0) {
        GOSTerr(GOST_F_GOST_KIMP15, ERR_R_INTERNAL_ERROR);
        goto err;
    }

    if (CRYPTO_memcmp(mac_buf, out + shared_len, mac_len) != 0) {
        GOSTerr(GOST_F_GOST_KIMP15, GOST_R_BAD_MAC);
        goto err;
    }

    memcpy(shared_key, out, shared_len);
    ret = 1;

 err:
    OPENSSL_cleanse(out, sizeof(out));
    EVP_MD_CTX_free(mac);
    EVP_CIPHER_CTX_free(ciph);
    return ret;
}

int gost_kdftree2012_256(unsigned char *keyout, size_t keyout_len,
                         const unsigned char *key, size_t keylen,
                         const unsigned char *label, size_t label_len,
                         const unsigned char *seed, size_t seed_len,
                         const size_t representation)
{
    int iters, i = 0;
    unsigned char zero = 0;
    unsigned char *ptr = keyout;
    HMAC_CTX *ctx;
    unsigned char *len_ptr = NULL;
    uint32_t len_repr = be32(keyout_len * 8);
    size_t len_repr_len = 4;

    ctx = HMAC_CTX_new();
    if (ctx == NULL) {
        GOSTerr(GOST_F_GOST_KDFTREE2012_256, ERR_R_MALLOC_FAILURE);
        return 0;
    }

    if ((keyout_len == 0) || (keyout_len % 32 != 0)) {
        GOSTerr(GOST_F_GOST_KDFTREE2012_256, ERR_R_INTERNAL_ERROR);
        return 0;
    }
    iters = keyout_len / 32;

    len_ptr = (unsigned char *)&len_repr;
    while (*len_ptr == 0) {
        len_ptr++;
        len_repr_len--;
    }

    for (i = 1; i <= iters; i++) {
        uint32_t iter_net = be32(i);
        unsigned char *rep_ptr =
            ((unsigned char *)&iter_net) + (4 - representation);

        if (HMAC_Init_ex(ctx, key, keylen,
                         EVP_get_digestbynid(NID_id_GostR3411_2012_256),
                         NULL) <= 0
            || HMAC_Update(ctx, rep_ptr, representation) <= 0
            || HMAC_Update(ctx, label, label_len) <= 0
            || HMAC_Update(ctx, &zero, 1) <= 0
            || HMAC_Update(ctx, seed, seed_len) <= 0
            || HMAC_Update(ctx, len_ptr, len_repr_len) <= 0
            || HMAC_Final(ctx, ptr, NULL) <= 0) {
            GOSTerr(GOST_F_GOST_KDFTREE2012_256, ERR_R_INTERNAL_ERROR);
            HMAC_CTX_free(ctx);
            return 0;
        }

        HMAC_CTX_reset(ctx);
        ptr += 32;
    }

    HMAC_CTX_free(ctx);

    return 1;
}

int gost_tlstree(int cipher_nid, const unsigned char *in, unsigned char *out,
                 const unsigned char *tlsseq)
{
    uint64_t gh_c1 = 0x00000000FFFFFFFF, gh_c2 = 0x0000F8FFFFFFFFFF,
        gh_c3 = 0xC0FFFFFFFFFFFFFF;
    uint64_t mg_c1 = 0x00000000C0FFFFFF, mg_c2 = 0x000000FEFFFFFFFF,
        mg_c3 = 0x00F0FFFFFFFFFFFF;
    uint64_t c1, c2, c3;
    uint64_t seed1, seed2, seed3;
    uint64_t seq;
    unsigned char ko1[32], ko2[32];

    switch (cipher_nid) {
    case NID_magma_cbc:
        c1 = mg_c1;
        c2 = mg_c2;
        c3 = mg_c3;
        break;
    case NID_grasshopper_cbc:
        c1 = gh_c1;
        c2 = gh_c2;
        c3 = gh_c3;
        break;
    default:
        return 0;
    }
#ifndef L_ENDIAN
    BUF_reverse((unsigned char *)&seq, tlsseq, 8);
#else
    memcpy(&seq, tlsseq, 8);
#endif
    seed1 = seq & c1;
    seed2 = seq & c2;
    seed3 = seq & c3;

    if (gost_kdftree2012_256(ko1, 32, in, 32, (const unsigned char *)"level1", 6,
                         (const unsigned char *)&seed1, 8, 1) <= 0
			  || gost_kdftree2012_256(ko2, 32, ko1, 32, (const unsigned char *)"level2", 6,
                         (const unsigned char *)&seed2, 8, 1) <= 0
        || gost_kdftree2012_256(out, 32, ko2, 32, (const unsigned char *)"level3", 6,
                         (const unsigned char *)&seed3, 8, 1) <= 0)
			return 0;

    return 1;
}

#define GOST_WRAP_FLAGS  EVP_CIPH_CTRL_INIT | EVP_CIPH_WRAP_MODE | EVP_CIPH_CUSTOM_IV | EVP_CIPH_FLAG_CUSTOM_CIPHER | EVP_CIPH_FLAG_DEFAULT_ASN1

#define MAGMA_MAC_WRAP_LEN 8
#define KUZNYECHIK_MAC_WRAP_LEN 16
#define MAX_MAC_WRAP_LEN KUZNYECHIK_MAC_WRAP_LEN
#define GOSTKEYLEN 32
#define MAGMA_WRAPPED_KEY_LEN GOSTKEYLEN + MAGMA_MAC_WRAP_LEN
#define KUZNYECHIK_WRAPPED_KEY_LEN GOSTKEYLEN + KUZNYECHIK_MAC_WRAP_LEN
#define MAX_WRAPPED_KEY_LEN KUZNYECHIK_WRAPPED_KEY_LEN

typedef struct {
	unsigned char iv[8];   /* Max IV size is half of base cipher block length */
	unsigned char key[GOSTKEYLEN*2]; /* Combined cipher and mac keys */
	unsigned char wrapped[MAX_WRAPPED_KEY_LEN]; /* Max size */
	size_t wrap_count;
} GOST_WRAP_CTX;

static int magma_wrap_init(EVP_CIPHER_CTX *ctx, const unsigned char *key,
	const unsigned char *iv, int enc)
{
	GOST_WRAP_CTX *cctx = EVP_CIPHER_CTX_get_cipher_data(ctx);
	memset(cctx->wrapped, 0, MAX_WRAPPED_KEY_LEN);
	cctx->wrap_count = 0;

	if (iv) {
		memset(cctx->iv, 0, 8);
		memcpy(cctx->iv, iv, 4);
	}

	if (key) {
		memcpy(cctx->key, key, GOSTKEYLEN*2);
	}
	return 1;
}

static int magma_wrap_do(EVP_CIPHER_CTX *ctx, unsigned char *out,
	const unsigned char *in, size_t inl)
{
	GOST_WRAP_CTX *cctx = EVP_CIPHER_CTX_get_cipher_data(ctx);
	int enc = EVP_CIPHER_CTX_encrypting(ctx) ? 1 : 0;

	if (out == NULL)
		return GOSTKEYLEN;

	if (inl <= MAGMA_WRAPPED_KEY_LEN) {
		if (cctx->wrap_count + inl > MAGMA_WRAPPED_KEY_LEN)
			return -1;

		if (cctx->wrap_count + inl <= MAGMA_WRAPPED_KEY_LEN)
		{
			memcpy(cctx->wrapped+cctx->wrap_count, in, inl);
			cctx->wrap_count += inl;
		}
	}

	if (cctx->wrap_count < MAGMA_WRAPPED_KEY_LEN)
		return 0;

	if (enc) {
#if 0
		return gost_kexp15(cctx->key, 32, NID_magma_ctr, in, NID_magma_mac,
			cctx->key, /* FIXME mac_key, */ cctx->iv, 4, out, &outl);
#endif
		return -1;
	} else {
		return gost_kimp15(cctx->wrapped, cctx->wrap_count, NID_magma_ctr,
		cctx->key+GOSTKEYLEN, NID_magma_mac, cctx->key, cctx->iv, 4, out) > 0 ? GOSTKEYLEN : 0;
	}
}

static int kuznyechik_wrap_init(EVP_CIPHER_CTX *ctx, const unsigned char *key,
	const unsigned char *iv, int enc)
{
	GOST_WRAP_CTX *cctx = EVP_CIPHER_CTX_get_cipher_data(ctx);
	memset(cctx->wrapped, 0, KUZNYECHIK_WRAPPED_KEY_LEN);
	cctx->wrap_count = 0;

	if (iv) {
		memset(cctx->iv, 0, 8);
		memcpy(cctx->iv, iv, 8);
	}

	if (key) {
		memcpy(cctx->key, key, GOSTKEYLEN*2);
	}
	return 1;
}

static int kuznyechik_wrap_do(EVP_CIPHER_CTX *ctx, unsigned char *out,
	const unsigned char *in, size_t inl)
{
	GOST_WRAP_CTX *cctx = EVP_CIPHER_CTX_get_cipher_data(ctx);
	int enc = EVP_CIPHER_CTX_encrypting(ctx) ? 1 : 0;

	if (out == NULL)
		return GOSTKEYLEN;

	if (inl <= KUZNYECHIK_WRAPPED_KEY_LEN) {
		if (cctx->wrap_count + inl > KUZNYECHIK_WRAPPED_KEY_LEN)
			return -1;

		if (cctx->wrap_count + inl <= KUZNYECHIK_WRAPPED_KEY_LEN)
		{
			memcpy(cctx->wrapped+cctx->wrap_count, in, inl);
			cctx->wrap_count += inl;
		}
	}

	if (cctx->wrap_count < KUZNYECHIK_WRAPPED_KEY_LEN)
		return 0;

	if (enc) {
#if 0
		return gost_kexp15(cctx->key, 32, NID_magma_ctr, in, NID_magma_mac,
			cctx->key, /* FIXME mac_key, */ cctx->iv, 4, out, &outl);
#endif
		return -1;
	} else {
		return gost_kimp15(cctx->wrapped, cctx->wrap_count, NID_kuznyechik_ctr,
		cctx->key+GOSTKEYLEN, NID_kuznyechik_mac, cctx->key, cctx->iv, 8, out) > 0 ? GOSTKEYLEN : 0;
	}
}

static int wrap_ctrl (EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr)
{
	switch(type)
	{
		case EVP_CTRL_INIT:
			EVP_CIPHER_CTX_set_flags(ctx, EVP_CIPHER_CTX_FLAG_WRAP_ALLOW);
			return 1;
		default:
			return -2;
	}
}

static GOST_cipher wrap_template_cipher = {
    .key_len = GOSTKEYLEN * 2,
    .flags = GOST_WRAP_FLAGS,
    .ctx_size = sizeof(GOST_WRAP_CTX),
    .ctrl = wrap_ctrl,
};

GOST_cipher magma_kexp15_cipher = {
    .template = &wrap_template_cipher,
    .nid = NID_magma_kexp15,
    .block_size = 8,
    .iv_len = 4,
    .init = magma_wrap_init,
    .do_cipher = magma_wrap_do,
};

GOST_cipher kuznyechik_kexp15_cipher = {
    .template = &wrap_template_cipher,
    .nid = NID_kuznyechik_kexp15,
    .block_size = 16,
    .iv_len = 8,
    .init = kuznyechik_wrap_init,
    .do_cipher = kuznyechik_wrap_do,
};
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
