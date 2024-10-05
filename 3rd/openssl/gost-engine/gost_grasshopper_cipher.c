/*
 * Maxim Tishkov 2016
 * Copyright (c) 2020 Vitaly Chikunov <vt@altlinux.org>
 * This file is distributed under the same license as OpenSSL
 */

#include "gost_grasshopper_cipher.h"
#include "gost_grasshopper_defines.h"
#include "gost_grasshopper_math.h"
#include "gost_grasshopper_core.h"
#include "gost_gost2015.h"

#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <string.h>

#include "gost_lcl.h"
#include "e_gost_err.h"

enum GRASSHOPPER_CIPHER_TYPE {
    GRASSHOPPER_CIPHER_ECB = 0,
    GRASSHOPPER_CIPHER_CBC,
    GRASSHOPPER_CIPHER_OFB,
    GRASSHOPPER_CIPHER_CFB,
    GRASSHOPPER_CIPHER_CTR,
    GRASSHOPPER_CIPHER_CTRACPKM,
    GRASSHOPPER_CIPHER_CTRACPKMOMAC,
    GRASSHOPPER_CIPHER_MGM,
};

static GOST_cipher grasshopper_template_cipher = {
    .block_size = GRASSHOPPER_BLOCK_SIZE,
    .key_len = GRASSHOPPER_KEY_SIZE,
    .flags = EVP_CIPH_RAND_KEY |
        EVP_CIPH_ALWAYS_CALL_INIT,
    .cleanup = gost_grasshopper_cipher_cleanup,
    .ctx_size = sizeof(gost_grasshopper_cipher_ctx),
    .set_asn1_parameters = gost_grasshopper_set_asn1_parameters,
    .get_asn1_parameters = gost_grasshopper_get_asn1_parameters,
    .ctrl = gost_grasshopper_cipher_ctl,
};

GOST_cipher grasshopper_ecb_cipher = {
    .nid = NID_grasshopper_ecb,
    .template = &grasshopper_template_cipher,
    .flags = EVP_CIPH_ECB_MODE,
    .init = gost_grasshopper_cipher_init_ecb,
    .do_cipher = gost_grasshopper_cipher_do_ecb,
};

GOST_cipher grasshopper_cbc_cipher = {
    .nid = NID_grasshopper_cbc,
    .template = &grasshopper_template_cipher,
    .iv_len = 16,
    .flags = EVP_CIPH_CBC_MODE |
        EVP_CIPH_CUSTOM_IV,
    .init = gost_grasshopper_cipher_init_cbc,
    .do_cipher = gost_grasshopper_cipher_do_cbc,
};

GOST_cipher grasshopper_ofb_cipher = {
    .nid = NID_grasshopper_ofb,
    .template = &grasshopper_template_cipher,
    .block_size = 1,
    .iv_len = 16,
    .flags = EVP_CIPH_OFB_MODE |
        EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV,
    .init = gost_grasshopper_cipher_init_ofb,
    .do_cipher = gost_grasshopper_cipher_do_ofb,
};

GOST_cipher grasshopper_cfb_cipher = {
    .nid = NID_grasshopper_cfb,
    .template = &grasshopper_template_cipher,
    .block_size = 1,
    .iv_len = 16,
    .flags = EVP_CIPH_CFB_MODE |
        EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV,
    .init = gost_grasshopper_cipher_init_cfb,
    .do_cipher = gost_grasshopper_cipher_do_cfb,
};

GOST_cipher grasshopper_ctr_cipher = {
    .nid = NID_grasshopper_ctr,
    .template = &grasshopper_template_cipher,
    .block_size = 1,
    .iv_len = 8,
    .flags = EVP_CIPH_CTR_MODE |
        EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV,
    .init = gost_grasshopper_cipher_init_ctr,
    .do_cipher = gost_grasshopper_cipher_do_ctr,
    .ctx_size = sizeof(gost_grasshopper_cipher_ctx_ctr),
};

GOST_cipher grasshopper_ctr_acpkm_cipher = {
    .nid = NID_kuznyechik_ctr_acpkm,
    .template = &grasshopper_template_cipher,
    .block_size = 1,
    .iv_len = 8,
    .flags = EVP_CIPH_CTR_MODE |
        EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV,
    .init = gost_grasshopper_cipher_init_ctracpkm,
    .do_cipher = gost_grasshopper_cipher_do_ctracpkm,
    .ctx_size = sizeof(gost_grasshopper_cipher_ctx_ctr),
};

GOST_cipher grasshopper_ctr_acpkm_omac_cipher = {
    .nid = NID_kuznyechik_ctr_acpkm_omac,
    .template = &grasshopper_template_cipher,
    .block_size = 1,
    .iv_len = 8,
    .flags = EVP_CIPH_CTR_MODE |
        EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV |
        EVP_CIPH_FLAG_CUSTOM_CIPHER |
        EVP_CIPH_FLAG_CIPHER_WITH_MAC |
        EVP_CIPH_CUSTOM_COPY,
    .init = gost_grasshopper_cipher_init_ctracpkm_omac,
    .do_cipher = gost_grasshopper_cipher_do_ctracpkm_omac,
    .ctx_size = sizeof(gost_grasshopper_cipher_ctx_ctr),
};

GOST_cipher grasshopper_mgm_cipher = {
    .nid = NID_undef,
    .template = &grasshopper_template_cipher,
    .block_size = 1,
    .iv_len = 16,
    .flags = EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV | EVP_CIPH_FLAG_CUSTOM_CIPHER |
        EVP_CIPH_CTRL_INIT | EVP_CIPH_FLAG_AEAD_CIPHER,
    .cleanup = gost_grasshopper_mgm_cleanup,
    .ctrl = gost_grasshopper_mgm_ctrl,
    .init = gost_grasshopper_cipher_init_mgm,
    .do_cipher = gost_grasshopper_cipher_do_mgm,
    .ctx_size = sizeof(gost_mgm_ctx)
};

static void kuznyechik_NID_callback (int nid)
{
    grasshopper_mgm_cipher.nid = nid;
}

GOST_NID_JOB kuznyechik_mgm_NID = {
    .sn = SN_kuznyechik_mgm,
    .ln = SN_kuznyechik_mgm,
    .callback = kuznyechik_NID_callback,
};

/* first 256 bit of D from draft-irtf-cfrg-re-keying-12 */
static const unsigned char ACPKM_D_2018[] = {
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, /*  64 bit */
    0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, /* 128 bit */
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97,
    0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f, /* 256 bit */
};

static void acpkm_next(gost_grasshopper_cipher_ctx * c)
{
    unsigned char newkey[GRASSHOPPER_KEY_SIZE];
    const int J = GRASSHOPPER_KEY_SIZE / GRASSHOPPER_BLOCK_SIZE;
    int n;

    for (n = 0; n < J; n++) {
        const unsigned char *D_n = &ACPKM_D_2018[n * GRASSHOPPER_BLOCK_SIZE];

        grasshopper_encrypt_block(&c->encrypt_round_keys,
                                  (grasshopper_w128_t *) D_n,
                                  (grasshopper_w128_t *) & newkey[n *
                                                                  GRASSHOPPER_BLOCK_SIZE],
                                  &c->buffer);
    }
    gost_grasshopper_cipher_key(c, newkey);
}

/* Set 256 bit  key into context */
static GRASSHOPPER_INLINE void
gost_grasshopper_cipher_key(gost_grasshopper_cipher_ctx * c, const uint8_t *k)
{
    int i;
    for (i = 0; i < 2; i++) {
        grasshopper_copy128(&c->key.k.k[i],
                            (const grasshopper_w128_t *)(k + i * 16));
    }

    grasshopper_set_encrypt_key(&c->encrypt_round_keys, &c->key);
    grasshopper_set_decrypt_key(&c->decrypt_round_keys, &c->key);
}

/* Set master 256-bit key to be used in TLSTREE calculation into context */
static GRASSHOPPER_INLINE void
gost_grasshopper_master_key(gost_grasshopper_cipher_ctx * c, const uint8_t *k)
{
    int i;
    for (i = 0; i < 2; i++) {
        grasshopper_copy128(&c->master_key.k.k[i],
                            (const grasshopper_w128_t *)(k + i * 16));
    }
}

/* Cleans up key from context */
static GRASSHOPPER_INLINE void
gost_grasshopper_cipher_destroy(gost_grasshopper_cipher_ctx * c)
{
    int i;
    for (i = 0; i < 2; i++) {
        grasshopper_zero128(&c->key.k.k[i]);
        grasshopper_zero128(&c->master_key.k.k[i]);
    }
    for (i = 0; i < GRASSHOPPER_ROUND_KEYS_COUNT; i++) {
        grasshopper_zero128(&c->encrypt_round_keys.k[i]);
    }
    for (i = 0; i < GRASSHOPPER_ROUND_KEYS_COUNT; i++) {
        grasshopper_zero128(&c->decrypt_round_keys.k[i]);
    }
    grasshopper_zero128(&c->buffer);
}

static GRASSHOPPER_INLINE void
gost_grasshopper_cipher_destroy_ctr(gost_grasshopper_cipher_ctx * c)
{
    gost_grasshopper_cipher_ctx_ctr *ctx =
        (gost_grasshopper_cipher_ctx_ctr *) c;

    if (ctx->omac_ctx)
        EVP_MD_CTX_free(ctx->omac_ctx);

    grasshopper_zero128(&ctx->partial_buffer);
}

static int gost_grasshopper_cipher_init(EVP_CIPHER_CTX *ctx,
                                 const unsigned char *key,
                                 const unsigned char *iv, int enc)
{
    gost_grasshopper_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);

    if (EVP_CIPHER_CTX_get_app_data(ctx) == NULL) {
        EVP_CIPHER_CTX_set_app_data(ctx, EVP_CIPHER_CTX_get_cipher_data(ctx));
        if (enc && c->type == GRASSHOPPER_CIPHER_CTRACPKM) {
            gost_grasshopper_cipher_ctx_ctr *ctr = EVP_CIPHER_CTX_get_cipher_data(ctx);
            if (init_zero_kdf_seed(ctr->kdf_seed) == 0)
                return -1;
        }
    }

    if (key != NULL) {
        gost_grasshopper_cipher_key(c, key);
        gost_grasshopper_master_key(c, key);
    }

    if (iv != NULL) {
        memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), iv,
               EVP_CIPHER_CTX_iv_length(ctx));
    }

    memcpy(EVP_CIPHER_CTX_iv_noconst(ctx),
           EVP_CIPHER_CTX_original_iv(ctx), EVP_CIPHER_CTX_iv_length(ctx));

    grasshopper_zero128(&c->buffer);

    return 1;
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_ecb(EVP_CIPHER_CTX *ctx, const unsigned char
                                 *key, const unsigned char
                                 *iv, int enc)
{
    gost_grasshopper_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    c->type = GRASSHOPPER_CIPHER_ECB;
    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_cbc(EVP_CIPHER_CTX *ctx, const unsigned char
                                 *key, const unsigned char
                                 *iv, int enc)
{
    gost_grasshopper_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    c->type = GRASSHOPPER_CIPHER_CBC;
    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

static GRASSHOPPER_INLINE
int gost_grasshopper_cipher_init_ofb(EVP_CIPHER_CTX *ctx, const unsigned char
                                     *key, const unsigned char
                                     *iv, int enc)
{
    gost_grasshopper_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    c->type = GRASSHOPPER_CIPHER_OFB;
    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_cfb(EVP_CIPHER_CTX *ctx, const unsigned char
                                 *key, const unsigned char
                                 *iv, int enc)
{
    gost_grasshopper_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    c->type = GRASSHOPPER_CIPHER_CFB;
    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_ctr(EVP_CIPHER_CTX *ctx, const unsigned char
                                 *key, const unsigned char
                                 *iv, int enc)
{
    gost_grasshopper_cipher_ctx_ctr *c = EVP_CIPHER_CTX_get_cipher_data(ctx);

    c->c.type = GRASSHOPPER_CIPHER_CTR;
    EVP_CIPHER_CTX_set_num(ctx, 0);

    grasshopper_zero128(&c->partial_buffer);

    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_ctracpkm(EVP_CIPHER_CTX
                                      *ctx, const unsigned
                                      char *key, const unsigned
                                      char *iv, int enc)
{
    gost_grasshopper_cipher_ctx_ctr *c = EVP_CIPHER_CTX_get_cipher_data(ctx);

    /* NB: setting type makes EVP do_cipher callback useless */
    c->c.type = GRASSHOPPER_CIPHER_CTRACPKM;
    EVP_CIPHER_CTX_set_num(ctx, 0);
    c->section_size = 4096;

    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_ctracpkm_omac(EVP_CIPHER_CTX
                                           *ctx, const unsigned
                                           char *key, const unsigned
                                           char *iv, int enc)
{
    gost_grasshopper_cipher_ctx_ctr *c = EVP_CIPHER_CTX_get_cipher_data(ctx);

    /* NB: setting type makes EVP do_cipher callback useless */
    c->c.type = GRASSHOPPER_CIPHER_CTRACPKMOMAC;
    EVP_CIPHER_CTX_set_num(ctx, 0);
    c->section_size = 4096;

    if (key) {
        unsigned char cipher_key[32];
        c->omac_ctx = EVP_MD_CTX_new();

        if (c->omac_ctx == NULL) {
            GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_INIT_CTRACPKM_OMAC, ERR_R_MALLOC_FAILURE);
            return 0;
        }

        if (gost2015_acpkm_omac_init(NID_kuznyechik_mac, enc, key,
           c->omac_ctx, cipher_key, c->kdf_seed) != 1) {
            EVP_MD_CTX_free(c->omac_ctx);
            c->omac_ctx = NULL;
            return 0;
        }

        return gost_grasshopper_cipher_init(ctx, cipher_key, iv, enc);
    }

    return gost_grasshopper_cipher_init(ctx, key, iv, enc);
}

// TODO: const *in, const *c
void gost_grasshopper_encrypt_wrap(unsigned char *in, unsigned char *out,
                   gost_grasshopper_cipher_ctx *c) {
    grasshopper_encrypt_block(&c->encrypt_round_keys,
                              (grasshopper_w128_t *) in,
                              (grasshopper_w128_t *) out,
                              &c->buffer);
}



/* ----------------------------------------------------------------------------------------------- */
/*! Функция реализует операцию умножения двух элементов конечного поля \f$ \mathbb F_{2^{128}}\f$,
    порожденного неприводимым многочленом
    \f$ f(x) = x^{128} + x^7 + x^2 + x + 1 \in \mathbb F_2[x]\f$. Для умножения используется
    простейшая реализация, основанная на приведении по модулю после каждого шага алгоритма.        */
/* ----------------------------------------------------------------------------------------------- */
static void gf128_mul_uint64 (uint64_t *result, uint64_t *arg1, uint64_t *arg2)
{
	int i = 0;
	register uint64_t t, X0, X1;
	uint64_t Z0 = 0, Z1 = 0;

#ifdef L_ENDIAN
	X0 = BSWAP64(*(arg1 + 1));
	X1 = BSWAP64(*arg1);
#else
	X0 = *(arg1 + 1);
	X1 = *arg1;
#endif

	//first 64 bits of arg1
#ifdef L_ENDIAN
	t = BSWAP64(*(arg2 + 1));
#else
	t = *(arg2 + 1);
#endif

	for (i = 0; i < 64; i++) {
		if (t & 0x1) {
			Z0 ^= X0;
			Z1 ^= X1;
		}
		t >>= 1;
		if (X1 & 0x8000000000000000) {
			X1 <<= 1;
			X1 ^= X0>>63;
			X0 <<= 1;
			X0 ^= 0x87;
		}
		else {
			X1 <<= 1;
			X1 ^= X0>>63;
			X0 <<= 1;
		}
	}

	//second 64 bits of arg2
#ifdef L_ENDIAN
	t = BSWAP64(*arg2);
#else
	t = *arg2;
#endif

	for (i = 0; i < 63; i++) {
		if (t & 0x1) {
			Z0 ^= X0;
			Z1 ^= X1;
		}
		t >>= 1;
		if (X1 & 0x8000000000000000) {
			X1 <<= 1;
			X1 ^= X0>>63;
			X0 <<= 1;
			X0 ^= 0x87;
		}
		else {
			X1 <<= 1;
			X1 ^= X0>>63;
			X0 <<= 1;
		}
	}

	if (t & 0x1) {
		Z0 ^= X0;
		Z1 ^= X1;
	}

#ifdef L_ENDIAN
	result[0] = BSWAP64(Z1);
	result[1] = BSWAP64(Z0);
#else
	result[0] = Z1;
	result[1] = Z0;
#endif
}

static GRASSHOPPER_INLINE int
gost_grasshopper_cipher_init_mgm(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                                 const unsigned char *iv, int enc)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(ctx);
    int bl;

    if (!iv && !key)
        return 1;
    if (key) {
        bl = EVP_CIPHER_CTX_iv_length(ctx);
        gost_grasshopper_cipher_key(&mctx->ks.gh_ks, key);
        gost_mgm128_init(&mctx->mgm, &mctx->ks,
                         (block128_f) gost_grasshopper_encrypt_wrap, gf128_mul_uint64, bl);

        /*
         * If we have an iv can set it directly, otherwise use saved IV.
         */
        if (iv == NULL && mctx->iv_set)
            iv = mctx->iv;
        if (iv) {
            if (gost_mgm128_setiv(&mctx->mgm, iv, mctx->ivlen) != 1)
                return 0;
            mctx->iv_set = 1;
        }
        mctx->key_set = 1;
    } else {
        /* If key set use IV, otherwise copy */
        if (mctx->key_set) {
            if (gost_mgm128_setiv(&mctx->mgm, iv, mctx->ivlen) != 1)
                return 0;
        }
        else
            memcpy(mctx->iv, iv, mctx->ivlen);
        mctx->iv_set = 1;
    }
    return 1;
}

static int gost_grasshopper_cipher_do_ecb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                          const unsigned char *in, size_t inl)
{
    gost_grasshopper_cipher_ctx *c =
        (gost_grasshopper_cipher_ctx *) EVP_CIPHER_CTX_get_cipher_data(ctx);
    bool encrypting = (bool) EVP_CIPHER_CTX_encrypting(ctx);
    const unsigned char *current_in = in;
    unsigned char *current_out = out;
    size_t blocks = inl / GRASSHOPPER_BLOCK_SIZE;
    size_t i;

    for (i = 0; i < blocks;
         i++, current_in += GRASSHOPPER_BLOCK_SIZE, current_out +=
         GRASSHOPPER_BLOCK_SIZE) {
        if (encrypting) {
            grasshopper_encrypt_block(&c->encrypt_round_keys,
                                      (grasshopper_w128_t *) current_in,
                                      (grasshopper_w128_t *) current_out,
                                      &c->buffer);
        } else {
            grasshopper_decrypt_block(&c->decrypt_round_keys,
                                      (grasshopper_w128_t *) current_in,
                                      (grasshopper_w128_t *) current_out,
                                      &c->buffer);
        }
    }

    return 1;
}

static int gost_grasshopper_cipher_do_cbc(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                          const unsigned char *in, size_t inl)
{
    gost_grasshopper_cipher_ctx *c =
        (gost_grasshopper_cipher_ctx *) EVP_CIPHER_CTX_get_cipher_data(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    bool encrypting = (bool) EVP_CIPHER_CTX_encrypting(ctx);
    const unsigned char *current_in = in;
    unsigned char *current_out = out;
    size_t blocks = inl / GRASSHOPPER_BLOCK_SIZE;
    size_t i;
    grasshopper_w128_t *currentBlock;

    currentBlock = (grasshopper_w128_t *) iv;

    for (i = 0; i < blocks;
         i++, current_in += GRASSHOPPER_BLOCK_SIZE, current_out +=
         GRASSHOPPER_BLOCK_SIZE) {
        grasshopper_w128_t *currentInputBlock = (grasshopper_w128_t *) current_in;
        grasshopper_w128_t *currentOutputBlock = (grasshopper_w128_t *) current_out;
        if (encrypting) {
            grasshopper_append128(currentBlock, currentInputBlock);
            grasshopper_encrypt_block(&c->encrypt_round_keys, currentBlock,
                                      currentOutputBlock, &c->buffer);
            grasshopper_copy128(currentBlock, currentOutputBlock);
        } else {
            grasshopper_w128_t tmp;

            grasshopper_copy128(&tmp, currentInputBlock);
            grasshopper_decrypt_block(&c->decrypt_round_keys,
                                      currentInputBlock, currentOutputBlock,
                                      &c->buffer);
            grasshopper_append128(currentOutputBlock, currentBlock);
            grasshopper_copy128(currentBlock, &tmp);
        }
    }

    return 1;
}

void inc_counter(unsigned char *counter, size_t counter_bytes)
{
    unsigned int n = counter_bytes;

    do {
        unsigned char c;
        --n;
        c = counter[n];
        ++c;
        counter[n] = c;
        if (c)
            return;
    } while (n);
}

/* increment counter (128-bit int) by 1 */
static void ctr128_inc(unsigned char *counter)
{
    inc_counter(counter, 16);
}

static int gost_grasshopper_cipher_do_ctr(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                          const unsigned char *in, size_t inl)
{
    gost_grasshopper_cipher_ctx_ctr *c = (gost_grasshopper_cipher_ctx_ctr *)
        EVP_CIPHER_CTX_get_cipher_data(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    const unsigned char *current_in = in;
    unsigned char *current_out = out;
    grasshopper_w128_t *currentInputBlock;
    grasshopper_w128_t *currentOutputBlock;
    unsigned int n = EVP_CIPHER_CTX_num(ctx);
    size_t lasted = inl;
    size_t i;
    size_t blocks;
    grasshopper_w128_t *iv_buffer;
    grasshopper_w128_t tmp;

    while (n && lasted) {
        *(current_out++) = *(current_in++) ^ c->partial_buffer.b[n];
        --lasted;
        n = (n + 1) % GRASSHOPPER_BLOCK_SIZE;
    }
    EVP_CIPHER_CTX_set_num(ctx, n);
    blocks = lasted / GRASSHOPPER_BLOCK_SIZE;

    iv_buffer = (grasshopper_w128_t *) iv;

    // full parts
    for (i = 0; i < blocks; i++) {
        currentInputBlock = (grasshopper_w128_t *) current_in;
        currentOutputBlock = (grasshopper_w128_t *) current_out;
        grasshopper_encrypt_block(&c->c.encrypt_round_keys, iv_buffer,
                                  &c->partial_buffer, &c->c.buffer);
        grasshopper_plus128(&tmp, &c->partial_buffer, currentInputBlock);
        grasshopper_copy128(currentOutputBlock, &tmp);
        ctr128_inc(iv_buffer->b);
        current_in += GRASSHOPPER_BLOCK_SIZE;
        current_out += GRASSHOPPER_BLOCK_SIZE;
        lasted -= GRASSHOPPER_BLOCK_SIZE;
    }

    if (lasted > 0) {
        currentInputBlock = (grasshopper_w128_t *) current_in;
        currentOutputBlock = (grasshopper_w128_t *) current_out;
        grasshopper_encrypt_block(&c->c.encrypt_round_keys, iv_buffer,
                                  &c->partial_buffer, &c->c.buffer);
        for (i = 0; i < lasted; i++) {
            currentOutputBlock->b[i] =
                c->partial_buffer.b[i] ^ currentInputBlock->b[i];
        }
        EVP_CIPHER_CTX_set_num(ctx, i);
        ctr128_inc(iv_buffer->b);
    }

    return inl;
}

#define GRASSHOPPER_BLOCK_MASK (GRASSHOPPER_BLOCK_SIZE - 1)
static inline void apply_acpkm_grasshopper(gost_grasshopper_cipher_ctx_ctr *
                                           ctx, unsigned int *num)
{
    if (!ctx->section_size || (*num < ctx->section_size))
        return;
    acpkm_next(&ctx->c);
    *num &= GRASSHOPPER_BLOCK_MASK;
}

/* If meshing is not configured via ctrl (setting section_size)
 * this function works exactly like plain ctr */
static int gost_grasshopper_cipher_do_ctracpkm(EVP_CIPHER_CTX *ctx,
                                               unsigned char *out,
                                               const unsigned char *in,
                                               size_t inl)
{
    gost_grasshopper_cipher_ctx_ctr *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    unsigned int num = EVP_CIPHER_CTX_num(ctx);
    size_t blocks, i, lasted = inl;
    grasshopper_w128_t tmp;

    while ((num & GRASSHOPPER_BLOCK_MASK) && lasted) {
        *out++ = *in++ ^ c->partial_buffer.b[num & GRASSHOPPER_BLOCK_MASK];
        --lasted;
        num++;
    }
    blocks = lasted / GRASSHOPPER_BLOCK_SIZE;

    // full parts
    for (i = 0; i < blocks; i++) {
        apply_acpkm_grasshopper(c, &num);
        grasshopper_encrypt_block(&c->c.encrypt_round_keys,
                                  (grasshopper_w128_t *) iv,
                                  (grasshopper_w128_t *) & c->partial_buffer,
                                  &c->c.buffer);
        grasshopper_plus128(&tmp, &c->partial_buffer,
                            (grasshopper_w128_t *) in);
        grasshopper_copy128((grasshopper_w128_t *) out, &tmp);
        ctr128_inc(iv);
        in += GRASSHOPPER_BLOCK_SIZE;
        out += GRASSHOPPER_BLOCK_SIZE;
        num += GRASSHOPPER_BLOCK_SIZE;
        lasted -= GRASSHOPPER_BLOCK_SIZE;
    }

    // last part
    if (lasted > 0) {
        apply_acpkm_grasshopper(c, &num);
        grasshopper_encrypt_block(&c->c.encrypt_round_keys,
                                  (grasshopper_w128_t *) iv,
                                  &c->partial_buffer, &c->c.buffer);
        for (i = 0; i < lasted; i++)
            out[i] = c->partial_buffer.b[i] ^ in[i];
        ctr128_inc(iv);
        num += lasted;
    }
    EVP_CIPHER_CTX_set_num(ctx, num);

    return inl;
}

static int gost_grasshopper_cipher_do_ctracpkm_omac(EVP_CIPHER_CTX *ctx,
                                                    unsigned char *out,
                                                    const unsigned char *in,
                                                    size_t inl)
{
    int result;
    gost_grasshopper_cipher_ctx_ctr *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    /* As in and out can be the same pointer, process unencrypted here */
    if (EVP_CIPHER_CTX_encrypting(ctx))
        EVP_DigestSignUpdate(c->omac_ctx, in, inl);

    if (in == NULL && inl == 0) { /* Final call */
        return gost2015_final_call(ctx, c->omac_ctx, KUZNYECHIK_MAC_MAX_SIZE, c->tag, gost_grasshopper_cipher_do_ctracpkm);
    }

    if (in == NULL) {
        GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_DO_CTRACPKM_OMAC, ERR_R_EVP_LIB);
        return -1;
    }
    result = gost_grasshopper_cipher_do_ctracpkm(ctx, out, in, inl);

    /* As in and out can be the same pointer, process decrypted here */
    if (!EVP_CIPHER_CTX_encrypting(ctx))
        EVP_DigestSignUpdate(c->omac_ctx, out, inl);

    return result;
}



static int gost_grasshopper_cipher_do_mgm(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                   const unsigned char *in, size_t len)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(ctx);
    int enc = EVP_CIPHER_CTX_encrypting(ctx);

    /* If not set up, return error */
    if (!mctx->key_set) {
        GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_DO_MGM,
                GOST_R_BAD_ORDER);
        return -1;
    }

    if (!mctx->iv_set) {
        GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_DO_MGM,
                GOST_R_BAD_ORDER);
        return -1;
    }
    if (in) {
        if (out == NULL) {
            if (gost_mgm128_aad(&mctx->mgm, in, len))
                return -1;
        } else if (enc) {
            if (gost_mgm128_encrypt(&mctx->mgm, in, out, len))
                return -1;
        } else {
            if (gost_mgm128_decrypt(&mctx->mgm, in, out, len))
                return -1;
        }
        return len;
    } else {
        if (!enc) {
            if (mctx->taglen < 0)
                return -1;
            if (gost_mgm128_finish(&mctx->mgm,
                                   EVP_CIPHER_CTX_buf_noconst(ctx),
                                   mctx->taglen) != 0)
                return -1;
            mctx->iv_set = 0;
            return 0;
        }
        gost_mgm128_tag(&mctx->mgm, EVP_CIPHER_CTX_buf_noconst(ctx), 16);
        mctx->taglen = 16;
        /* Don't reuse the IV */
        mctx->iv_set = 0;
        return 0;
    }

}

/*
 * Fixed 128-bit IV implementation make shift regiser redundant.
 */
static void gost_grasshopper_cnt_next(gost_grasshopper_cipher_ctx * ctx,
                                      grasshopper_w128_t * iv,
                                      grasshopper_w128_t * buf)
{
    grasshopper_w128_t tmp;
    memcpy(&tmp, iv, 16);
    grasshopper_encrypt_block(&ctx->encrypt_round_keys, &tmp,
                              buf, &ctx->buffer);
    memcpy(iv, buf, 16);
}

static int gost_grasshopper_cipher_do_ofb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                          const unsigned char *in, size_t inl)
{
    gost_grasshopper_cipher_ctx *c = (gost_grasshopper_cipher_ctx *)
        EVP_CIPHER_CTX_get_cipher_data(ctx);
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    unsigned char *buf = EVP_CIPHER_CTX_buf_noconst(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    int num = EVP_CIPHER_CTX_num(ctx);
    size_t i = 0;
    size_t j;

    /* process partial block if any */
    if (num > 0) {
        for (j = (size_t)num, i = 0; j < GRASSHOPPER_BLOCK_SIZE && i < inl;
             j++, i++, in_ptr++, out_ptr++) {
            *out_ptr = buf[j] ^ (*in_ptr);
        }
        if (j == GRASSHOPPER_BLOCK_SIZE) {
            EVP_CIPHER_CTX_set_num(ctx, 0);
        } else {
            EVP_CIPHER_CTX_set_num(ctx, (int)j);
            return 1;
        }
    }

    for (; i + GRASSHOPPER_BLOCK_SIZE <
         inl;
         i += GRASSHOPPER_BLOCK_SIZE, in_ptr +=
         GRASSHOPPER_BLOCK_SIZE, out_ptr += GRASSHOPPER_BLOCK_SIZE) {
        /*
         * block cipher current iv
         */
        /* Encrypt */
        gost_grasshopper_cnt_next(c, (grasshopper_w128_t *) iv,
                                  (grasshopper_w128_t *) buf);

        /*
         * xor next block of input text with it and output it
         */
        /*
         * output this block
         */
        for (j = 0; j < GRASSHOPPER_BLOCK_SIZE; j++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
    }

    /* Process rest of buffer */
    if (i < inl) {
        gost_grasshopper_cnt_next(c, (grasshopper_w128_t *) iv,
                                  (grasshopper_w128_t *) buf);
        for (j = 0; i < inl; j++, i++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        EVP_CIPHER_CTX_set_num(ctx, (int)j);
    } else {
        EVP_CIPHER_CTX_set_num(ctx, 0);
    }

    return 1;
}

static int gost_grasshopper_cipher_do_cfb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                          const unsigned char *in, size_t inl)
{
    gost_grasshopper_cipher_ctx *c =
        (gost_grasshopper_cipher_ctx *) EVP_CIPHER_CTX_get_cipher_data(ctx);
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    unsigned char *buf = EVP_CIPHER_CTX_buf_noconst(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    bool encrypting = (bool) EVP_CIPHER_CTX_encrypting(ctx);
    int num = EVP_CIPHER_CTX_num(ctx);
    size_t i = 0;
    size_t j = 0;

    /* process partial block if any */
    if (num > 0) {
        for (j = (size_t)num, i = 0; j < GRASSHOPPER_BLOCK_SIZE && i < inl;
             j++, i++, in_ptr++, out_ptr++) {
            if (!encrypting) {
                buf[j + GRASSHOPPER_BLOCK_SIZE] = *in_ptr;
            }
            *out_ptr = buf[j] ^ (*in_ptr);
            if (encrypting) {
                buf[j + GRASSHOPPER_BLOCK_SIZE] = *out_ptr;
            }
        }
        if (j == GRASSHOPPER_BLOCK_SIZE) {
            memcpy(iv, buf + GRASSHOPPER_BLOCK_SIZE, GRASSHOPPER_BLOCK_SIZE);
            EVP_CIPHER_CTX_set_num(ctx, 0);
        } else {
            EVP_CIPHER_CTX_set_num(ctx, (int)j);
            return 1;
        }
    }

    for (; i + GRASSHOPPER_BLOCK_SIZE <
         inl;
         i += GRASSHOPPER_BLOCK_SIZE, in_ptr +=
         GRASSHOPPER_BLOCK_SIZE, out_ptr += GRASSHOPPER_BLOCK_SIZE) {
        /*
         * block cipher current iv
         */
        grasshopper_encrypt_block(&c->encrypt_round_keys,
                                  (grasshopper_w128_t *) iv,
                                  (grasshopper_w128_t *) buf, &c->buffer);
        /*
         * xor next block of input text with it and output it
         */
        /*
         * output this block
         */
        if (!encrypting) {
            memcpy(iv, in_ptr, GRASSHOPPER_BLOCK_SIZE);
        }
        for (j = 0; j < GRASSHOPPER_BLOCK_SIZE; j++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        /* Encrypt */
        /* Next iv is next block of cipher text */
        if (encrypting) {
            memcpy(iv, out_ptr, GRASSHOPPER_BLOCK_SIZE);
        }
    }

    /* Process rest of buffer */
    if (i < inl) {
        grasshopper_encrypt_block(&c->encrypt_round_keys,
                                  (grasshopper_w128_t *) iv,
                                  (grasshopper_w128_t *) buf, &c->buffer);
        if (!encrypting) {
            memcpy(buf + GRASSHOPPER_BLOCK_SIZE, in_ptr, inl - i);
        }
        for (j = 0; i < inl; j++, i++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        EVP_CIPHER_CTX_set_num(ctx, (int)j);
        if (encrypting) {
            memcpy(buf + GRASSHOPPER_BLOCK_SIZE, out_ptr, j);
        }
    } else {
        EVP_CIPHER_CTX_set_num(ctx, 0);
    }

    return 1;
}

static int gost_grasshopper_cipher_cleanup(EVP_CIPHER_CTX *ctx)
{
    gost_grasshopper_cipher_ctx *c =
        (gost_grasshopper_cipher_ctx *) EVP_CIPHER_CTX_get_cipher_data(ctx);

    if (!c)
        return 1;

    if (EVP_CIPHER_CTX_mode(ctx) == EVP_CIPH_CTR_MODE)
        gost_grasshopper_cipher_destroy_ctr(c);

    EVP_CIPHER_CTX_set_app_data(ctx, NULL);

    return 1;
}

static int gost_grasshopper_set_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params)
{
    if (EVP_CIPHER_CTX_mode(ctx) == EVP_CIPH_CTR_MODE) {
        gost_grasshopper_cipher_ctx_ctr *ctr = EVP_CIPHER_CTX_get_cipher_data(ctx);

        /* CMS implies 256kb section_size */
        ctr->section_size = 256*1024;

        return gost2015_set_asn1_params(params,
               EVP_CIPHER_CTX_original_iv(ctx), 8, ctr->kdf_seed);
    }
    return 0;
}

static GRASSHOPPER_INLINE int
gost_grasshopper_get_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params)
{
    if (EVP_CIPHER_CTX_mode(ctx) == EVP_CIPH_CTR_MODE) {
        gost_grasshopper_cipher_ctx_ctr *ctr = EVP_CIPHER_CTX_get_cipher_data(ctx);

        int iv_len = 16;
        unsigned char iv[16];

        if (gost2015_get_asn1_params(params, 16, iv, 8, ctr->kdf_seed) == 0) {
            return 0;
        }

        memcpy(EVP_CIPHER_CTX_iv_noconst(ctx), iv, iv_len);
        memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), iv, iv_len);

        /* CMS implies 256kb section_size */
        ctr->section_size = 256*1024;
        return 1;
    }
    return 0;
}

static int gost_grasshopper_mgm_cleanup(EVP_CIPHER_CTX *c)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(c);
    if (mctx == NULL)
        return 0;
    gost_grasshopper_cipher_destroy(&mctx->ks.gh_ks);
    OPENSSL_cleanse(&mctx->mgm, sizeof(mctx->mgm));
    if (mctx->iv != EVP_CIPHER_CTX_iv_noconst(c))
        OPENSSL_free(mctx->iv);
    return 1;
}

static int gost_grasshopper_mgm_ctrl(EVP_CIPHER_CTX *c, int type, int arg, void *ptr)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(c);
    unsigned char *buf, *iv;
    int ivlen, enc;

    switch (type) {
    case EVP_CTRL_INIT:
        ivlen = EVP_CIPHER_iv_length(EVP_CIPHER_CTX_cipher(c));
        iv = EVP_CIPHER_CTX_iv_noconst(c);
        mctx->key_set = 0;
        mctx->iv_set = 0;
        mctx->ivlen = ivlen;
        mctx->iv = iv;
        mctx->taglen = -1;
        return 1;

    case EVP_CTRL_GET_IVLEN:
        *(int *)ptr = mctx->ivlen;
        return 1;

    case EVP_CTRL_AEAD_SET_IVLEN:
        if (arg <= 0)
            return 0;
        if ((arg > EVP_MAX_IV_LENGTH) && (arg > mctx->ivlen)) {
            // TODO: Allocate memory for IV or set error
            return 0;
        }
        mctx->ivlen = arg;
        return 1;

    case EVP_CTRL_AEAD_SET_TAG:
        buf = EVP_CIPHER_CTX_buf_noconst(c);
        enc = EVP_CIPHER_CTX_encrypting(c);
        if (arg <= 0 || arg != 16 || enc) {
            GOSTerr(GOST_F_GOST_GRASSHOPPER_MGM_CTRL,
                    GOST_R_INVALID_TAG_LENGTH);
            return 0;
        }
        memcpy(buf, ptr, arg);
        mctx->taglen = arg;
        return 1;

    case EVP_CTRL_AEAD_GET_TAG:
        buf = EVP_CIPHER_CTX_buf_noconst(c);
        enc = EVP_CIPHER_CTX_encrypting(c);
        if (arg <= 0 || arg > 16 || !enc || mctx->taglen < 0) {
            GOSTerr(GOST_F_GOST_GRASSHOPPER_MGM_CTRL,
                    GOST_R_INVALID_TAG_LENGTH);
            return 0;
        }
        memcpy(ptr, buf, arg);
        return 1;

    default:
        return -1;
    }
}

static int gost_grasshopper_cipher_ctl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr)
{
    switch (type) {
    case EVP_CTRL_RAND_KEY:{
            if (RAND_priv_bytes
                ((unsigned char *)ptr, EVP_CIPHER_CTX_key_length(ctx)) <= 0) {
                GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_CTL, GOST_R_RNG_ERROR);
                return -1;
            }
            break;
        }
    case EVP_CTRL_KEY_MESH:{
            gost_grasshopper_cipher_ctx_ctr *c =
                EVP_CIPHER_CTX_get_cipher_data(ctx);
            if ((c->c.type != GRASSHOPPER_CIPHER_CTRACPKM &&
                c->c.type != GRASSHOPPER_CIPHER_CTRACPKMOMAC)
                || (arg == 0)
               || (arg % GRASSHOPPER_BLOCK_SIZE))
                return -1;
            c->section_size = arg;
            break;
        }
    case EVP_CTRL_TLSTREE:
        {
          unsigned char newkey[32];
          int mode = EVP_CIPHER_CTX_mode(ctx);
          gost_grasshopper_cipher_ctx_ctr *ctr_ctx = NULL;
          gost_grasshopper_cipher_ctx *c = NULL;

          unsigned char adjusted_iv[16];
          unsigned char seq[8];
          int j, carry, decrement_arg;
          if (mode != EVP_CIPH_CTR_MODE)
              return -1;

          ctr_ctx = (gost_grasshopper_cipher_ctx_ctr *)
              EVP_CIPHER_CTX_get_cipher_data(ctx);
          c = &(ctr_ctx->c);

          /*
           * 'arg' parameter indicates what we should do with sequence value.
           * 
           * When function called, seq is incremented after MAC calculation.
           * In ETM mode, we use seq 'as is' in the ctrl-function (arg = 0)
           * Otherwise we have to decrease it in the implementation (arg = 1).
           */
          memcpy(seq, ptr, 8);
          decrement_arg = arg;
          if (!decrement_sequence(seq, decrement_arg))
          {
              GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_CTL, GOST_R_CTRL_CALL_FAILED);
              return -1;
          }

          if (gost_tlstree(NID_grasshopper_cbc, c->master_key.k.b, newkey,
                (const unsigned char *)seq) > 0) {
            memset(adjusted_iv, 0, 16);
            memcpy(adjusted_iv, EVP_CIPHER_CTX_original_iv(ctx), 8);
            for(j=7,carry=0; j>=0; j--)
            {
              int adj_byte = adjusted_iv[j]+seq[j]+carry;
              carry = (adj_byte > 255) ? 1 : 0;
              adjusted_iv[j] = adj_byte & 0xFF;
            }
            EVP_CIPHER_CTX_set_num(ctx, 0);
            memcpy(EVP_CIPHER_CTX_iv_noconst(ctx), adjusted_iv, 16);

            gost_grasshopper_cipher_key(c, newkey);
            return 1;
          }
        }
        return -1;
#if 0
    case EVP_CTRL_AEAD_GET_TAG:
    case EVP_CTRL_AEAD_SET_TAG:
        {
            int taglen = arg;
            unsigned char *tag = ptr;

            gost_grasshopper_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
            if (c->c.type != GRASSHOPPER_CIPHER_MGM)
                return -1;

            if (taglen > KUZNYECHIK_MAC_MAX_SIZE) {
                CRYPTOCOMerr(CRYPTOCOM_F_GOST_GRASSHOPPER_CIPHER_CTL,
                        CRYPTOCOM_R_INVALID_TAG_LENGTH);
                return -1;
            }

            if (type == EVP_CTRL_AEAD_GET_TAG)
                memcpy(tag, c->final_tag, taglen);
            else
                memcpy(c->final_tag, tag, taglen);

            return 1;
        }
#endif
    case EVP_CTRL_PROCESS_UNPROTECTED:
    {
      STACK_OF(X509_ATTRIBUTE) *x = ptr;
      gost_grasshopper_cipher_ctx_ctr *c = EVP_CIPHER_CTX_get_cipher_data(ctx);

      if (c->c.type != GRASSHOPPER_CIPHER_CTRACPKMOMAC)
        return -1;

      return gost2015_process_unprotected_attributes(x, arg, KUZNYECHIK_MAC_MAX_SIZE, c->tag);
    }
    case EVP_CTRL_COPY: {
        EVP_CIPHER_CTX *out = ptr;

        gost_grasshopper_cipher_ctx_ctr *out_cctx = EVP_CIPHER_CTX_get_cipher_data(out);
        gost_grasshopper_cipher_ctx_ctr *in_cctx  = EVP_CIPHER_CTX_get_cipher_data(ctx);

        if (in_cctx->c.type != GRASSHOPPER_CIPHER_CTRACPKMOMAC)
            return -1;

        if (in_cctx->omac_ctx == out_cctx->omac_ctx) {
            out_cctx->omac_ctx = EVP_MD_CTX_new();
            if (out_cctx->omac_ctx == NULL) {
                GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_CTL, ERR_R_MALLOC_FAILURE);
                return -1;
            }
        }
        return EVP_MD_CTX_copy(out_cctx->omac_ctx, in_cctx->omac_ctx);
    }
    default:
        GOSTerr(GOST_F_GOST_GRASSHOPPER_CIPHER_CTL,
                GOST_R_UNSUPPORTED_CIPHER_CTL_COMMAND);
        return -1;
    }
    return 1;
}

/* Called directly by CMAC_ACPKM_Init() */
const EVP_CIPHER *cipher_gost_grasshopper_ctracpkm()
{
    return GOST_init_cipher(&grasshopper_ctr_acpkm_cipher);
}
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
