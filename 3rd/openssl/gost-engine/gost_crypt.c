/**********************************************************************
 *             gost_crypt.c - Initialize all ciphers                  *
 *                                                                    *
 *             Copyright (c) 2005-2006 Cryptocom LTD                  *
 *             Copyright (c) 2020 Chikunov Vitaly <vt@altlinux.org>   *
 *         This file is distributed under the same license as OpenSSL *
 *                                                                    *
 *       OpenSSL interface to GOST 28147-89 cipher functions          *
 *          Requires OpenSSL 0.9.9 for compilation                    *
 **********************************************************************/
#include <string.h>
#include "gost89.h"
#include <openssl/err.h>
#include <openssl/rand.h>
#include "e_gost_err.h"
#include "gost_lcl.h"
#include "gost_gost2015.h"

#if !defined(CCGOST_DEBUG) && !defined(DEBUG)
# ifndef NDEBUG
#  define NDEBUG
# endif
#endif
#include <assert.h>

static int gost_cipher_init(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                            const unsigned char *iv, int enc);
static int gost_cipher_init_cbc(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                                const unsigned char *iv, int enc);
static int gost_cipher_init_cpa(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                                const unsigned char *iv, int enc);
static int gost_cipher_init_cp_12(EVP_CIPHER_CTX *ctx,
                                  const unsigned char *key,
                                  const unsigned char *iv, int enc);
/* Handles block of data in CFB mode */
static int gost_cipher_do_cfb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                              const unsigned char *in, size_t inl);
/* Handles block of data in CBC mode */
static int gost_cipher_do_cbc(EVP_CIPHER_CTX *ctx, unsigned char *out,
                              const unsigned char *in, size_t inl);
/* Handles block of data in CNT mode */
static int gost_cipher_do_cnt(EVP_CIPHER_CTX *ctx, unsigned char *out,
                              const unsigned char *in, size_t inl);
/* Cleanup function */
static int gost_cipher_cleanup(EVP_CIPHER_CTX *);
static int gost_magma_mgm_cleanup(EVP_CIPHER_CTX *c);
/* set/get cipher parameters */
static int gost89_set_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params);
static int gost89_get_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params);
/* Control function */
static int gost_cipher_ctl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr);

static int magma_cipher_init(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                             const unsigned char *iv, int enc);
static int magma_cipher_init_ctr_acpkm_omac(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                             const unsigned char *iv, int enc);
static int gost_magma_cipher_init_mgm(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                                 const unsigned char *iv, int enc);
/* Handles block of data in CBC mode */
static int magma_cipher_do_ecb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               const unsigned char *in, size_t inl);
static int magma_cipher_do_cbc(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               const unsigned char *in, size_t inl);
static int magma_cipher_do_ctr(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               const unsigned char *in, size_t inl);

static int magma_cipher_do_ctr_acpkm_omac(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               const unsigned char *in, size_t inl);
static int gost_magma_cipher_do_mgm(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                   const unsigned char *in, size_t len);
/* set/get cipher parameters */
static int magma_set_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params);
static int magma_get_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params);
/* Control function */
static int magma_cipher_ctl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr);
static int magma_cipher_ctl_acpkm_omac(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr);
static int gost_magma_mgm_ctrl(EVP_CIPHER_CTX *c, int type, int arg, void *ptr);

/*
 * Single level template accessor.
 * Note: that you cannot template 0 value.
 */
#define TPL(st,field) ( \
    ((st)->field) ? ((st)->field) : TPL_VAL(st,field) \
)

#define TPL_VAL(st,field) ( \
    ((st)->template ? (st)->template->field : 0) \
)

EVP_CIPHER *GOST_init_cipher(GOST_cipher *c)
{
    if (c->cipher)
        return c->cipher;

    /* Some sanity checking. */
    int flags = c->flags | TPL_VAL(c, flags);
    int block_size = TPL(c, block_size);
    switch (flags & EVP_CIPH_MODE) {
    case EVP_CIPH_CBC_MODE:
    case EVP_CIPH_ECB_MODE:
    case EVP_CIPH_WRAP_MODE:
        OPENSSL_assert(block_size != 1);
        OPENSSL_assert(!(flags & EVP_CIPH_NO_PADDING));
        break;
    default:
        OPENSSL_assert(block_size == 1);
        OPENSSL_assert(flags & EVP_CIPH_NO_PADDING);
    }

    if (TPL(c, iv_len))
        OPENSSL_assert(flags & EVP_CIPH_CUSTOM_IV);
    else
        OPENSSL_assert(!(flags & EVP_CIPH_CUSTOM_IV));

    EVP_CIPHER *cipher;
    if (!(cipher = EVP_CIPHER_meth_new(c->nid, block_size, TPL(c, key_len)))
        || !EVP_CIPHER_meth_set_iv_length(cipher, TPL(c, iv_len))
        || !EVP_CIPHER_meth_set_flags(cipher, flags)
        || !EVP_CIPHER_meth_set_init(cipher, TPL(c, init))
        || !EVP_CIPHER_meth_set_do_cipher(cipher, TPL(c, do_cipher))
        || !EVP_CIPHER_meth_set_cleanup(cipher, TPL(c, cleanup))
        || !EVP_CIPHER_meth_set_impl_ctx_size(cipher, TPL(c, ctx_size))
        || !EVP_CIPHER_meth_set_set_asn1_params(cipher, TPL(c, set_asn1_parameters))
        || !EVP_CIPHER_meth_set_get_asn1_params(cipher, TPL(c, get_asn1_parameters))
        || !EVP_CIPHER_meth_set_ctrl(cipher, TPL(c, ctrl))) {
        EVP_CIPHER_meth_free(cipher);
        cipher = NULL;
    }
    c->cipher = cipher;
    return c->cipher;
}

void GOST_deinit_cipher(GOST_cipher *c)
{
    if (c->cipher) {
        EVP_CIPHER_meth_free(c->cipher);
        c->cipher = NULL;
    }
}

static GOST_cipher gost_template_cipher = {
    .block_size = 8,
    .key_len = 32,
    .iv_len = 8,
    .flags = EVP_CIPH_CUSTOM_IV |
        EVP_CIPH_RAND_KEY |
        EVP_CIPH_ALWAYS_CALL_INIT,
    .cleanup = gost_cipher_cleanup,
    .ctx_size = sizeof(struct ossl_gost_cipher_ctx),
    .set_asn1_parameters = gost89_set_asn1_parameters,
    .get_asn1_parameters = gost89_get_asn1_parameters,
    .ctrl = gost_cipher_ctl,
};

GOST_cipher Gost28147_89_cipher = {
    .nid = NID_id_Gost28147_89,
    .template = &gost_template_cipher,
    .block_size = 1,
    .flags = EVP_CIPH_CFB_MODE |
        EVP_CIPH_NO_PADDING,
    .init = gost_cipher_init,
    .do_cipher = gost_cipher_do_cfb,
};

GOST_cipher Gost28147_89_cbc_cipher = {
    .nid = NID_gost89_cbc,
    .template = &gost_template_cipher,
    .flags = EVP_CIPH_CBC_MODE,
    .init = gost_cipher_init_cbc,
    .do_cipher = gost_cipher_do_cbc,
};

GOST_cipher Gost28147_89_cnt_cipher = {
    .nid = NID_gost89_cnt,
    .template = &gost_template_cipher,
    .block_size = 1,
    .flags = EVP_CIPH_OFB_MODE |
        EVP_CIPH_NO_PADDING,
    .init = gost_cipher_init_cpa,
    .do_cipher = gost_cipher_do_cnt,
};

GOST_cipher Gost28147_89_cnt_12_cipher = {
    .nid = NID_gost89_cnt_12,
    .template = &gost_template_cipher,
    .block_size = 1,
    .flags = EVP_CIPH_OFB_MODE |
        EVP_CIPH_NO_PADDING,
    .init = gost_cipher_init_cp_12,
    .do_cipher = gost_cipher_do_cnt,
};

static GOST_cipher magma_template_cipher = {
    .block_size = 8,
    .key_len = 32,
    .flags =
        EVP_CIPH_RAND_KEY |
        EVP_CIPH_ALWAYS_CALL_INIT,
    .cleanup = gost_cipher_cleanup,
    .ctx_size = sizeof(struct ossl_gost_cipher_ctx),
    .set_asn1_parameters = magma_set_asn1_parameters,
    .get_asn1_parameters = magma_get_asn1_parameters,
    .do_cipher = magma_cipher_do_ctr,
    .ctrl = magma_cipher_ctl,
};

GOST_cipher magma_ctr_cipher = {
    .nid = NID_magma_ctr,
    .template = &magma_template_cipher,
    .block_size = 1,
    .iv_len = 4,
    .flags = EVP_CIPH_CTR_MODE |
        EVP_CIPH_CUSTOM_IV |
        EVP_CIPH_NO_PADDING,
    .init = magma_cipher_init,
};

GOST_cipher magma_ctr_acpkm_cipher = {
    .nid = NID_magma_ctr_acpkm,
    .template = &magma_template_cipher,
    .block_size = 1,
    .iv_len = 4,
    .flags = EVP_CIPH_CTR_MODE |
        EVP_CIPH_CUSTOM_IV |
        EVP_CIPH_NO_PADDING,
    .init = magma_cipher_init,
};

GOST_cipher magma_ctr_acpkm_omac_cipher = {
    .nid = NID_magma_ctr_acpkm_omac,
    .template = &magma_template_cipher,
    .block_size = 1,
    .iv_len = 4,
    .flags = EVP_CIPH_CTR_MODE |
        EVP_CIPH_CUSTOM_IV |
        EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_COPY |
        EVP_CIPH_FLAG_CUSTOM_CIPHER |
        EVP_CIPH_FLAG_CIPHER_WITH_MAC,
    .init = magma_cipher_init_ctr_acpkm_omac,
    .do_cipher = magma_cipher_do_ctr_acpkm_omac,
    .ctrl = magma_cipher_ctl_acpkm_omac,
};

GOST_cipher magma_ecb_cipher = {
    .nid = NID_magma_ecb,
    .template = &magma_template_cipher,
    .flags = EVP_CIPH_ECB_MODE,
    .init = magma_cipher_init,
    .do_cipher = magma_cipher_do_ecb,
};

 GOST_cipher magma_mgm_cipher = {
    .nid = NID_undef,
    .template = &magma_template_cipher,
    .block_size = 1,
    .iv_len = 8,
    .flags = EVP_CIPH_NO_PADDING |
        EVP_CIPH_CUSTOM_IV | EVP_CIPH_FLAG_CUSTOM_CIPHER |
        EVP_CIPH_CTRL_INIT | EVP_CIPH_FLAG_AEAD_CIPHER,
    .init = gost_magma_cipher_init_mgm,
    .do_cipher = gost_magma_cipher_do_mgm,
    .ctrl = gost_magma_mgm_ctrl,
    .cleanup = gost_magma_mgm_cleanup,
    .ctx_size = sizeof(gost_mgm_ctx)
 };

static void magma_NID_callback (int nid)
{
    magma_mgm_cipher.nid = nid;
}

GOST_NID_JOB magma_mgm_NID = {
    .sn = SN_magma_mgm,
    .ln = SN_magma_mgm,
    .callback = magma_NID_callback,
};

GOST_cipher magma_cbc_cipher = {
    .nid = NID_magma_cbc,
    .template = &gost_template_cipher,
    .iv_len = 8,
    .flags = EVP_CIPH_CBC_MODE |
        EVP_CIPH_CUSTOM_IV,
    .init = magma_cipher_init,
    .do_cipher = magma_cipher_do_cbc,
};

/* Implementation of GOST 28147-89 in MAC (imitovstavka) mode */
/* Init functions which set specific parameters */
static int gost_imit_init_cpa(EVP_MD_CTX *ctx);
static int gost_imit_init_cp_12(EVP_MD_CTX *ctx);
/* process block of data */
static int gost_imit_update(EVP_MD_CTX *ctx, const void *data, size_t count);
/* Return computed value */
static int gost_imit_final(EVP_MD_CTX *ctx, unsigned char *md);
/* Copies context */
static int gost_imit_copy(EVP_MD_CTX *to, const EVP_MD_CTX *from);
static int gost_imit_cleanup(EVP_MD_CTX *ctx);
/* Control function, knows how to set MAC key.*/
static int gost_imit_ctrl(EVP_MD_CTX *ctx, int type, int arg, void *ptr);

GOST_digest Gost28147_89_MAC_digest = {
    .nid = NID_id_Gost28147_89_MAC,
    .result_size = 4,
    .input_blocksize = 8,
    .app_datasize = sizeof(struct ossl_gost_imit_ctx),
    .flags = EVP_MD_FLAG_XOF,
    .init = gost_imit_init_cpa,
    .update = gost_imit_update,
    .final = gost_imit_final,
    .copy = gost_imit_copy,
    .cleanup = gost_imit_cleanup,
    .ctrl = gost_imit_ctrl,
};

GOST_digest Gost28147_89_mac_12_digest = {
    .nid = NID_gost_mac_12,
    .result_size = 4,
    .input_blocksize = 8,
    .app_datasize = sizeof(struct ossl_gost_imit_ctx),
    .flags = EVP_MD_FLAG_XOF,
    .init = gost_imit_init_cp_12,
    .update = gost_imit_update,
    .final = gost_imit_final,
    .copy = gost_imit_copy,
    .cleanup = gost_imit_cleanup,
    .ctrl = gost_imit_ctrl,
};

/*
 * Correspondence between gost parameter OIDs and substitution blocks
 * NID field is filed by register_gost_NID function in engine.c
 * upon engine initialization
 */

static struct gost_cipher_info gost_cipher_list[] = {
    /*- NID *//*
     * Subst block
     *//*
     * Key meshing
     */
    /*
     * {NID_id_GostR3411_94_CryptoProParamSet,&GostR3411_94_CryptoProParamSet,0},
     */
    {NID_id_Gost28147_89_CryptoPro_A_ParamSet, &Gost28147_CryptoProParamSetA,
     1},
    {NID_id_Gost28147_89_CryptoPro_B_ParamSet, &Gost28147_CryptoProParamSetB,
     1},
    {NID_id_Gost28147_89_CryptoPro_C_ParamSet, &Gost28147_CryptoProParamSetC,
     1},
    {NID_id_Gost28147_89_CryptoPro_D_ParamSet, &Gost28147_CryptoProParamSetD,
     1},
    {NID_id_tc26_gost_28147_param_Z, &Gost28147_TC26ParamSetZ, 1},
    {NID_id_Gost28147_89_TestParamSet, &Gost28147_TestParamSet, 1},
    {NID_undef, NULL, 0}
};

/*
 * get encryption parameters from crypto network settings FIXME For now we
 * use environment var CRYPT_PARAMS as place to store these settings.
 * Actually, it is better to use engine control command, read from
 * configuration file to set them
 */
const struct gost_cipher_info *get_encryption_params(ASN1_OBJECT *obj)
{
    int nid;
    struct gost_cipher_info *param;
    if (!obj) {
        const char *params = get_gost_engine_param(GOST_PARAM_CRYPT_PARAMS);
        if (!params || !strlen(params)) {
            int i;
            for (i = 0; gost_cipher_list[i].nid != NID_undef; i++)
                if (gost_cipher_list[i].nid == NID_id_tc26_gost_28147_param_Z)
                    return &gost_cipher_list[i];
            return &gost_cipher_list[0];
        }

        nid = OBJ_txt2nid(params);
        if (nid == NID_undef) {
            GOSTerr(GOST_F_GET_ENCRYPTION_PARAMS,
                    GOST_R_INVALID_CIPHER_PARAM_OID);
            ERR_add_error_data(3, "Unsupported CRYPT_PARAMS='",
                params, "' specified in environment or in config");
            return NULL;
        }
    } else {
        nid = OBJ_obj2nid(obj);
    }
    for (param = gost_cipher_list; param->sblock != NULL && param->nid != nid;
         param++) ;
    if (!param->sblock) {
        GOSTerr(GOST_F_GET_ENCRYPTION_PARAMS, GOST_R_INVALID_CIPHER_PARAMS);
        return NULL;
    }
    return param;
}

/* Sets cipher param from paramset NID. */
static int gost_cipher_set_param(struct ossl_gost_cipher_ctx *c, int nid)
{
    const struct gost_cipher_info *param;
    param = get_encryption_params((nid == NID_undef ? NULL : OBJ_nid2obj(nid)));
    if (!param)
        return 0;

    c->paramNID = param->nid;
    c->key_meshing = param->key_meshing;
    c->count = 0;
    gost_init(&(c->cctx), param->sblock);
    return 1;
}

/* Initializes EVP_CIPHER_CTX by paramset NID */
static int gost_cipher_init_param(EVP_CIPHER_CTX *ctx,
                                  const unsigned char *key,
                                  const unsigned char *iv, int enc,
                                  int paramNID, int mode)
{
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    if (EVP_CIPHER_CTX_get_app_data(ctx) == NULL) {
        if (!gost_cipher_set_param(c, paramNID))
            return 0;
        EVP_CIPHER_CTX_set_app_data(ctx, EVP_CIPHER_CTX_get_cipher_data(ctx));
    }
    if (key)
        gost_key(&(c->cctx), key);
    if (iv) {
        memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), iv,
               EVP_CIPHER_CTX_iv_length(ctx));
    }
    memcpy(EVP_CIPHER_CTX_iv_noconst(ctx),
           EVP_CIPHER_CTX_original_iv(ctx), EVP_CIPHER_CTX_iv_length(ctx));
    return 1;
}

static int gost_cipher_init_cnt(EVP_CIPHER_CTX *ctx,
                                const unsigned char *key,
                                const unsigned char *iv,
                                gost_subst_block * block)
{
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    gost_init(&(c->cctx), block);
    c->key_meshing = 1;
    c->count = 0;
    if (key)
        gost_key(&(c->cctx), key);
    if (iv) {
        memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), iv,
               EVP_CIPHER_CTX_iv_length(ctx));
    }
    memcpy(EVP_CIPHER_CTX_iv_noconst(ctx),
           EVP_CIPHER_CTX_original_iv(ctx), EVP_CIPHER_CTX_iv_length(ctx));
    return 1;
}

static int gost_cipher_init_cpa(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                                const unsigned char *iv, int enc)
{
    return gost_cipher_init_cnt(ctx, key, iv, &Gost28147_CryptoProParamSetA);
}

static int gost_cipher_init_cp_12(EVP_CIPHER_CTX *ctx,
                                  const unsigned char *key,
                                  const unsigned char *iv, int enc)
{
    return gost_cipher_init_cnt(ctx, key, iv, &Gost28147_TC26ParamSetZ);
}

/* Initializes EVP_CIPHER_CTX with default values */
static int gost_cipher_init(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                     const unsigned char *iv, int enc)
{
    return gost_cipher_init_param(ctx, key, iv, enc, NID_undef,
                                  EVP_CIPH_CFB_MODE);
}

/* Initializes EVP_CIPHER_CTX with default values */
static int gost_cipher_init_cbc(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                         const unsigned char *iv, int enc)
{
    return gost_cipher_init_param(ctx, key, iv, enc, NID_undef,
                                  EVP_CIPH_CBC_MODE);
}

/* Initializes EVP_CIPHER_CTX with default values */
static int magma_cipher_init(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                      const unsigned char *iv, int enc)
{
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    /* FIXME this is just initializtion check */
    if (EVP_CIPHER_CTX_get_app_data(ctx) == NULL) {
        if (!gost_cipher_set_param(c, NID_id_tc26_gost_28147_param_Z))
            return 0;
        EVP_CIPHER_CTX_set_app_data(ctx, EVP_CIPHER_CTX_get_cipher_data(ctx));

        if (enc) {
            if (init_zero_kdf_seed(c->kdf_seed) == 0)
                return -1;
        }
    }

    if (key) {
        magma_key(&(c->cctx), key);
        magma_master_key(&(c->cctx), key);
    }
    if (iv) {
        memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), iv,
               EVP_CIPHER_CTX_iv_length(ctx));
    }
    memcpy(EVP_CIPHER_CTX_iv_noconst(ctx),
           EVP_CIPHER_CTX_original_iv(ctx), EVP_CIPHER_CTX_iv_length(ctx));

    if (EVP_CIPHER_CTX_nid(ctx) == NID_magma_ctr_acpkm
     || EVP_CIPHER_CTX_nid(ctx) == NID_magma_ctr_acpkm_omac) {
       c->key_meshing = 1024;
    } else {
       c->key_meshing = 0;
    }

    return 1;
}

/* Initializes EVP_CIPHER_CTX with default values */
static int magma_cipher_init_ctr_acpkm_omac(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                      const unsigned char *iv, int enc)
{
	if (key) {
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
		unsigned char cipher_key[32];
		c->omac_ctx = EVP_MD_CTX_new();

		if (c->omac_ctx == NULL) {
		    GOSTerr(GOST_F_MAGMA_CIPHER_INIT_CTR_ACPKM_OMAC, ERR_R_MALLOC_FAILURE);
				return 0;
		}

		if (gost2015_acpkm_omac_init(NID_magma_mac, enc, key,
		                 c->omac_ctx, cipher_key, c->kdf_seed) != 1) {
		    EVP_MD_CTX_free(c->omac_ctx);
				c->omac_ctx = NULL;
		    return 0;
		}

		return magma_cipher_init(ctx, cipher_key, iv, enc);
	}

	return magma_cipher_init(ctx, key, iv, enc);
}

void gost_magma_encrypt_wrap(unsigned char *in, unsigned char *out,
                   struct ossl_gost_cipher_ctx *c) {
    int i;
    unsigned char b[8];
    unsigned char d[8];
    for (i = 0; i < 8; i++) {
        b[7 - i] = in[i];
    }
    gostcrypt(&(c->cctx), b, d);
    for (i = 0; i < 8; i++) {
        out[7 - i] = d[i];
    }
}

/* ----------------------------------------------------------------------------------------------- */
/*! Функция реализует операцию умножения двух элементов конечного поля \f$ \mathbb F_{2^{64}}\f$,
    порожденного неприводимым многочленом
    \f$ f(x) = x^{64} + x^4 + x^3 + x + 1 \in \mathbb F_2[x]\f$. Для умножения используется
    простейшая реализация, основанная на приведении по модулю после каждого шага алгоритма.        */
/* ----------------------------------------------------------------------------------------------- */
static void gf64_mul (uint64_t *result, uint64_t *arg1, uint64_t *arg2)
{
	int i = 0;
	register uint64_t t, X0;
	uint64_t Z0 = 0;

#ifdef L_ENDIAN
	X0 = BSWAP64(*arg1);
#else
	X0 = *arg1;
#endif

#ifdef L_ENDIAN
	t = BSWAP64(*(arg2));
#else
	t = *(arg2);
#endif

	for (i = 0; i < 63; i++) {
		if (t & 0x1) {
			Z0 ^= X0;
		}
		t >>= 1;
		if (X0 & 0x8000000000000000) {
			X0 <<= 1;
			X0 ^= 0x1b;
		}
		else {
			X0 <<= 1;
		}
	}

	if (t & 0x1) {
		Z0 ^= X0;
	}

#ifdef L_ENDIAN
	*(result) = BSWAP64(Z0);
#else
	*(result) = Z0;
#endif
}

static int gost_magma_cipher_init_mgm(EVP_CIPHER_CTX *ctx, const unsigned char *key,
                                 const unsigned char *iv, int enc)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(ctx);
    int bl;

    if (!iv && !key)
        return 1;
    if (key) {
        bl = EVP_CIPHER_CTX_iv_length(ctx);
        if (!gost_cipher_set_param(&mctx->ks.g_ks, NID_id_tc26_gost_28147_param_Z))
            return 0;
        magma_key(&(mctx->ks.g_ks.cctx), key);
        gost_mgm128_init(&mctx->mgm, &mctx->ks,
                         (block128_f) gost_magma_encrypt_wrap, gf64_mul, bl);

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

/*
 * Wrapper around gostcrypt function from gost89.c which perform key meshing
 * when nesseccary
 */
static void gost_crypt_mesh(void *ctx, unsigned char *iv, unsigned char *buf)
{
    struct ossl_gost_cipher_ctx *c = ctx;
    assert(c->count % 8 == 0 && c->count <= 1024);
    if (c->key_meshing && c->count == 1024) {
        cryptopro_key_meshing(&(c->cctx), iv);
    }
    gostcrypt(&(c->cctx), iv, buf);
    c->count = c->count % 1024 + 8;
}

static void gost_cnt_next(void *ctx, unsigned char *iv, unsigned char *buf)
{
    struct ossl_gost_cipher_ctx *c = ctx;
    word32 g, go;
    unsigned char buf1[8];
    assert(c->count % 8 == 0 && c->count <= 1024);
    if (c->key_meshing && c->count == 1024) {
        cryptopro_key_meshing(&(c->cctx), iv);
    }
    if (c->count == 0) {
        gostcrypt(&(c->cctx), iv, buf1);
    } else {
        memcpy(buf1, iv, 8);
    }
    g = buf1[0] | (buf1[1] << 8) | (buf1[2] << 16) | ((word32) buf1[3] << 24);
    g += 0x01010101;
    buf1[0] = (unsigned char)(g & 0xff);
    buf1[1] = (unsigned char)((g >> 8) & 0xff);
    buf1[2] = (unsigned char)((g >> 16) & 0xff);
    buf1[3] = (unsigned char)((g >> 24) & 0xff);
    g = buf1[4] | (buf1[5] << 8) | (buf1[6] << 16) | ((word32) buf1[7] << 24);
    go = g;
    g += 0x01010104;
    if (go > g)                 /* overflow */
        g++;
    buf1[4] = (unsigned char)(g & 0xff);
    buf1[5] = (unsigned char)((g >> 8) & 0xff);
    buf1[6] = (unsigned char)((g >> 16) & 0xff);
    buf1[7] = (unsigned char)((g >> 24) & 0xff);
    memcpy(iv, buf1, 8);
    gostcrypt(&(c->cctx), buf1, buf);
    c->count = c->count % 1024 + 8;
}

/* GOST encryption in CBC mode */
static int gost_cipher_do_cbc(EVP_CIPHER_CTX *ctx, unsigned char *out,
                       const unsigned char *in, size_t inl)
{
    unsigned char b[8];
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    int i;
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    if (EVP_CIPHER_CTX_encrypting(ctx)) {
        while (inl > 0) {

            for (i = 0; i < 8; i++) {
                b[i] = iv[i] ^ in_ptr[i];
            }
            gostcrypt(&(c->cctx), b, out_ptr);
            memcpy(iv, out_ptr, 8);
            out_ptr += 8;
            in_ptr += 8;
            inl -= 8;
        }
    } else {
        while (inl > 0) {
            unsigned char tmpiv[8];
            gostdecrypt(&(c->cctx), in_ptr, b);
            memcpy(tmpiv, in_ptr, 8);
            for (i = 0; i < 8; i++) {
                out_ptr[i] = iv[i] ^ b[i];
            }
            memcpy(iv, tmpiv, 8);
            out_ptr += 8;
            in_ptr += 8;
            inl -= 8;
        }
    }
    return 1;
}

/* MAGMA encryption in ECB mode */
static int magma_cipher_do_ecb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                        const unsigned char *in, size_t inl)
{
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    if (EVP_CIPHER_CTX_encrypting(ctx)) {
        while (inl > 0) {
            magmacrypt(&(c->cctx), in, out);
            out += 8;
            in += 8;
            inl -= 8;
        }
    } else {
        while (inl > 0) {
            magmadecrypt(&(c->cctx), in, out);
            out += 8;
            in += 8;
            inl -= 8;
        }
    }
    return 1;
}

/* MAGMA encryption in CBC mode */
static int magma_cipher_do_cbc(EVP_CIPHER_CTX *ctx, unsigned char *out,
                        const unsigned char *in, size_t inl)
{
    unsigned char b[8];
    unsigned char d[8];
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    int i;
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    if (EVP_CIPHER_CTX_encrypting(ctx)) {
        while (inl > 0) {

            for (i = 0; i < 8; i++) {
                out_ptr[i] = iv[i] ^ in_ptr[i];
            }
            magmacrypt(&(c->cctx), out_ptr, out_ptr);
            memcpy(iv, out_ptr, 8);
            out_ptr += 8;
            in_ptr += 8;
            inl -= 8;
        }
    } else {
        while (inl > 0) {
            magmadecrypt(&(c->cctx), in_ptr, b);
            memcpy(d, in_ptr, 8);
            for (i = 0; i < 8; i++) {
                out_ptr[i] = iv[i] ^ b[i];
            }
            memcpy(iv, d, 8);
            out_ptr += 8;
            in_ptr += 8;
            inl -= 8;
        }
    }
    return 1;
}

/* increment counter (64-bit int) by 1 */
static void ctr64_inc(unsigned char *counter)
{
    inc_counter(counter, 8);
}

#define MAGMA_BLOCK_SIZE 8
#define MAGMA_BLOCK_MASK (MAGMA_BLOCK_SIZE - 1)
static inline void apply_acpkm_magma(struct ossl_gost_cipher_ctx *
                                           ctx, unsigned int *num)
{
    if (!ctx->key_meshing || (*num < (unsigned int)ctx->key_meshing))
        return;
    acpkm_magma_key_meshing(&ctx->cctx);
    *num &= MAGMA_BLOCK_MASK;
}

/* MAGMA encryption in CTR mode */
static int magma_cipher_do_ctr(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               const unsigned char *in, size_t inl)
{
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    size_t j;
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    unsigned char *buf = EVP_CIPHER_CTX_buf_noconst(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
    unsigned int num = EVP_CIPHER_CTX_num(ctx);
    size_t blocks, i, lasted = inl;
/* Process partial blocks */
    while ((num & MAGMA_BLOCK_MASK) && lasted) {
        *out_ptr++ = *in_ptr++ ^ buf[num & MAGMA_BLOCK_MASK];
        --lasted;
        num++;
    }
    blocks = lasted / MAGMA_BLOCK_SIZE;

/* Process full blocks */
    for (i = 0; i < blocks; i++) {
        apply_acpkm_magma(c, &num);
        magmacrypt(&(c->cctx), iv, buf);
        for (j = 0; j < 8; j++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        ctr64_inc(iv);
        c->count += MAGMA_BLOCK_SIZE;
        in_ptr += MAGMA_BLOCK_SIZE;
        out_ptr += MAGMA_BLOCK_SIZE;
        num += MAGMA_BLOCK_SIZE;
        lasted -= MAGMA_BLOCK_SIZE;
    }

/* Process the rest of plaintext */
    if (lasted > 0) {
        apply_acpkm_magma(c, &num);
        magmacrypt(&(c->cctx), iv, buf);

        for (i = 0; i < lasted; i++)
            out_ptr[i] = buf[i] ^ in_ptr[i];
        ctr64_inc(iv);
        c->count += 8;
        num += lasted;
    }
    EVP_CIPHER_CTX_set_num(ctx, num);

    return inl;
}

/* MAGMA encryption in CTR mode */
static int magma_cipher_do_ctr_acpkm_omac(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               const unsigned char *in, size_t inl)
{
  struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);

	if (in == NULL && inl == 0) /* Final call */
		return gost2015_final_call(ctx, c->omac_ctx, MAGMA_MAC_MAX_SIZE, c->tag, magma_cipher_do_ctr);

  if (in == NULL)
      return -1;

	/* As in and out can be the same pointer, process unencrypted here */
	if (EVP_CIPHER_CTX_encrypting(ctx))
		EVP_DigestSignUpdate(c->omac_ctx, in, inl);

  if (magma_cipher_do_ctr(ctx, out, in, inl) != inl)
      return -1;

	/* As in and out can be the same pointer, process decrypted here */
	if (!EVP_CIPHER_CTX_encrypting(ctx))
		EVP_DigestSignUpdate(c->omac_ctx, out, inl);

	return inl;
}

static int gost_magma_cipher_do_mgm(EVP_CIPHER_CTX *ctx, unsigned char *out,
                                   const unsigned char *in, size_t len)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(ctx);
    int enc = EVP_CIPHER_CTX_encrypting(ctx);

    /* If not set up, return error */
    if (!mctx->key_set) {
        GOSTerr(GOST_F_GOST_MAGMA_CIPHER_DO_MGM,
                GOST_R_BAD_ORDER);
        return -1;
    }

    if (!mctx->iv_set) {
        GOSTerr(GOST_F_GOST_MAGMA_CIPHER_DO_MGM,
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
        gost_mgm128_tag(&mctx->mgm, EVP_CIPHER_CTX_buf_noconst(ctx), 8);
        mctx->taglen = 8;
        /* Don't reuse the IV */
        mctx->iv_set = 0;
        return 0;
    }

}

/* GOST encryption in CFB mode */
static int gost_cipher_do_cfb(EVP_CIPHER_CTX *ctx, unsigned char *out,
                       const unsigned char *in, size_t inl)
{
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    size_t i = 0;
    size_t j = 0;
    unsigned char *buf = EVP_CIPHER_CTX_buf_noconst(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
/* process partial block if any */
    if (EVP_CIPHER_CTX_num(ctx)) {
        for (j = EVP_CIPHER_CTX_num(ctx), i = 0; j < 8 && i < inl;
             j++, i++, in_ptr++, out_ptr++) {
            if (!EVP_CIPHER_CTX_encrypting(ctx))
                buf[j + 8] = *in_ptr;
            *out_ptr = buf[j] ^ (*in_ptr);
            if (EVP_CIPHER_CTX_encrypting(ctx))
                buf[j + 8] = *out_ptr;
        }
        if (j == 8) {
            memcpy(iv, buf + 8, 8);
            EVP_CIPHER_CTX_set_num(ctx, 0);
        } else {
            EVP_CIPHER_CTX_set_num(ctx, j);
            return 1;
        }
    }

    for (; (inl - i) >= 8; i += 8, in_ptr += 8, out_ptr += 8) {
        /*
         * block cipher current iv
         */
        gost_crypt_mesh(EVP_CIPHER_CTX_get_cipher_data(ctx), iv, buf);
        /*
         * xor next block of input text with it and output it
         */
        /*
         * output this block
         */
        if (!EVP_CIPHER_CTX_encrypting(ctx))
            memcpy(iv, in_ptr, 8);
        for (j = 0; j < 8; j++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        /* Encrypt */
        /* Next iv is next block of cipher text */
        if (EVP_CIPHER_CTX_encrypting(ctx))
            memcpy(iv, out_ptr, 8);
    }
/* Process rest of buffer */
    if (i < inl) {
        gost_crypt_mesh(EVP_CIPHER_CTX_get_cipher_data(ctx), iv, buf);
        if (!EVP_CIPHER_CTX_encrypting(ctx))
            memcpy(buf + 8, in_ptr, inl - i);
        for (j = 0; i < inl; j++, i++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        EVP_CIPHER_CTX_set_num(ctx, j);
        if (EVP_CIPHER_CTX_encrypting(ctx))
            memcpy(buf + 8, out_ptr, j);
    } else {
        EVP_CIPHER_CTX_set_num(ctx, 0);
    }
    return 1;
}

static int gost_cipher_do_cnt(EVP_CIPHER_CTX *ctx, unsigned char *out,
                              const unsigned char *in, size_t inl)
{
    const unsigned char *in_ptr = in;
    unsigned char *out_ptr = out;
    size_t i = 0;
    size_t j;
    unsigned char *buf = EVP_CIPHER_CTX_buf_noconst(ctx);
    unsigned char *iv = EVP_CIPHER_CTX_iv_noconst(ctx);
/* process partial block if any */
    if (EVP_CIPHER_CTX_num(ctx)) {
        for (j = EVP_CIPHER_CTX_num(ctx), i = 0; j < 8 && i < inl;
             j++, i++, in_ptr++, out_ptr++) {
            *out_ptr = buf[j] ^ (*in_ptr);
        }
        if (j == 8) {
            EVP_CIPHER_CTX_set_num(ctx, 0);
        } else {
            EVP_CIPHER_CTX_set_num(ctx, j);
            return 1;
        }
    }

    for (; (inl - i) >= 8; i += 8, in_ptr += 8, out_ptr += 8) {
        /*
         * block cipher current iv
         */
        /* Encrypt */
        gost_cnt_next(EVP_CIPHER_CTX_get_cipher_data(ctx), iv, buf);
        /*
         * xor next block of input text with it and output it
         */
        /*
         * output this block
         */
        for (j = 0; j < 8; j++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
    }
/* Process rest of buffer */
    if (i < inl) {
        gost_cnt_next(EVP_CIPHER_CTX_get_cipher_data(ctx), iv, buf);
        for (j = 0; i < inl; j++, i++) {
            out_ptr[j] = buf[j] ^ in_ptr[j];
        }
        EVP_CIPHER_CTX_set_num(ctx, j);
    } else {
        EVP_CIPHER_CTX_set_num(ctx, 0);
    }
    return 1;
}

/* Cleaning up of EVP_CIPHER_CTX */
static int gost_cipher_cleanup(EVP_CIPHER_CTX *ctx)
{
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
		EVP_MD_CTX_free(c->omac_ctx);
    gost_destroy(&(c->cctx));
    EVP_CIPHER_CTX_set_app_data(ctx, NULL);
    return 1;
}

static int gost_magma_mgm_cleanup(EVP_CIPHER_CTX *c)
{
    gost_mgm_ctx *mctx =
        (gost_mgm_ctx *)EVP_CIPHER_CTX_get_cipher_data(c);
    if (mctx == NULL)
        return 0;
    gost_destroy(&mctx->ks.g_ks.cctx);
    OPENSSL_cleanse(&mctx->mgm, sizeof(mctx->mgm));
    EVP_CIPHER_CTX_set_app_data(c, NULL);
    return 1;
}

static int gost_magma_mgm_ctrl(EVP_CIPHER_CTX *c, int type, int arg, void *ptr)
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
        if (arg <= 0 || arg != 8 || enc) {
            GOSTerr(GOST_F_GOST_MAGMA_MGM_CTRL,
                    GOST_R_INVALID_TAG_LENGTH);
            return 0;
        }
        memcpy(buf, ptr, arg);
        mctx->taglen = arg;
        return 1;

    case EVP_CTRL_AEAD_GET_TAG:
        buf = EVP_CIPHER_CTX_buf_noconst(c);
        enc = EVP_CIPHER_CTX_encrypting(c);
        if (arg <= 0 || arg > 8 || !enc || mctx->taglen < 0) {
            GOSTerr(GOST_F_GOST_MAGMA_MGM_CTRL,
                    GOST_R_INVALID_TAG_LENGTH);
            return 0;
        }
        memcpy(ptr, buf, arg);
        return 1;

    default:
        return -1;
    }
}

/* Control function for gost cipher */
static int gost_cipher_ctl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr)
{
    switch (type) {
    case EVP_CTRL_RAND_KEY:
        {
            if (RAND_priv_bytes
                ((unsigned char *)ptr, EVP_CIPHER_CTX_key_length(ctx)) <= 0) {
                GOSTerr(GOST_F_GOST_CIPHER_CTL, GOST_R_RNG_ERROR);
                return -1;
            }
            break;
        }
    case EVP_CTRL_PBE_PRF_NID:
        if (ptr) {
            const char *params = get_gost_engine_param(GOST_PARAM_PBE_PARAMS);
            int nid = NID_id_tc26_hmac_gost_3411_2012_512;

            if (params) {
                if (!strcmp("md_gost12_256", params))
                    nid = NID_id_tc26_hmac_gost_3411_2012_256;
                else if (!strcmp("md_gost12_512", params))
                    nid = NID_id_tc26_hmac_gost_3411_2012_512;
                else if (!strcmp("md_gost94", params))
                    nid = NID_id_HMACGostR3411_94;
            }
            *((int *)ptr) = nid;
            return 1;
        } else {
            return 0;
        }

    case EVP_CTRL_SET_SBOX:
        if (ptr) {
            struct ossl_gost_cipher_ctx *c =
                EVP_CIPHER_CTX_get_cipher_data(ctx);
            int nid;
            int cur_meshing;
            int ret;

            if (c == NULL) {
                return -1;
            }

            if (c->count != 0) {
                return -1;
            }

            nid = OBJ_txt2nid(ptr);
            if (nid == NID_undef) {
                return 0;
            }

            cur_meshing = c->key_meshing;
            ret = gost_cipher_set_param(c, nid);
            c->key_meshing = cur_meshing;
            return ret;
        } else {
            return 0;
        }
    case EVP_CTRL_KEY_MESH:
        {
            struct ossl_gost_cipher_ctx *c =
                EVP_CIPHER_CTX_get_cipher_data(ctx);

            if (c == NULL) {
                return -1;
            }

            if (c->count != 0) {
                return -1;
            }

            c->key_meshing = arg;
            return 1;
        }
    default:
        GOSTerr(GOST_F_GOST_CIPHER_CTL, GOST_R_UNSUPPORTED_CIPHER_CTL_COMMAND);
        return -1;
    }
    return 1;
}

/* Decrement 8-byte sequence if needed */
int decrement_sequence(unsigned char *seq, int decrement) {
    if (decrement < 0 || decrement > 1)
        return 0; 
    
    int j;
    if (decrement) {
       for (j = 7; j >= 0; j--)
            {
                if (seq[j] != 0)
                {
                    seq[j]--;
                    break;
                }
                else
                    seq[j] = 0xFF;
            }
    }
    return 1;
}

/* Control function for gost cipher */
static int magma_cipher_ctl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr)
{
    switch (type) {
    case EVP_CTRL_RAND_KEY:
            if (RAND_priv_bytes
                ((unsigned char *)ptr, EVP_CIPHER_CTX_key_length(ctx)) <= 0) {
                GOSTerr(GOST_F_MAGMA_CIPHER_CTL, GOST_R_RNG_ERROR);
                return -1;
            }
            break;
    case EVP_CTRL_KEY_MESH:
        {
            struct ossl_gost_cipher_ctx *c =
                EVP_CIPHER_CTX_get_cipher_data(ctx);

            if (c == NULL) {
                return -1;
            }

            if (c->count != 0) {
                return -1;
            }

            c->key_meshing = arg;
            return 1;
        }
    case EVP_CTRL_TLSTREE:
        {
            unsigned char newkey[32];
            int mode = EVP_CIPHER_CTX_mode(ctx);
            struct ossl_gost_cipher_ctx *ctr_ctx = NULL;
            gost_ctx *c = NULL;

            unsigned char adjusted_iv[8];
            unsigned char seq[8];
            int j, carry, decrement_arg;
            if (mode != EVP_CIPH_CTR_MODE)
                return -1;

            ctr_ctx = (struct ossl_gost_cipher_ctx *)EVP_CIPHER_CTX_get_cipher_data(ctx);
            c = &(ctr_ctx->cctx);

            /*
             * 'arg' parameter indicates what we should do with sequence value.
             * 
             * When function called, seq is incremented after MAC calculation.
             * In ETM mode, we use seq 'as is' in the ctrl-function (arg = 0)
             * Otherwise we have to decrease it in the implementation (arg = 1).
             */
            memcpy(seq, ptr, 8);
            decrement_arg = arg;
            if(!decrement_sequence(seq, decrement_arg)) {
                GOSTerr(GOST_F_MAGMA_CIPHER_CTL, GOST_R_CTRL_CALL_FAILED);
                return -1;
            }

            if (gost_tlstree(NID_magma_cbc, (const unsigned char *)c->master_key, newkey,
                             (const unsigned char *)seq) > 0) {
                memset(adjusted_iv, 0, 8);
                memcpy(adjusted_iv, EVP_CIPHER_CTX_original_iv(ctx), 4);
                for (j = 3, carry = 0; j >= 0; j--)
                {
                    int adj_byte = adjusted_iv[j] + seq[j+4] + carry;
                    carry = (adj_byte > 255) ? 1 : 0;
                    adjusted_iv[j] = adj_byte & 0xFF;
                }
                EVP_CIPHER_CTX_set_num(ctx, 0);
                memcpy(EVP_CIPHER_CTX_iv_noconst(ctx), adjusted_iv, 8);

                magma_key(c, newkey);
                return 1;
          }
        }
        return -1;
    default:
        GOSTerr(GOST_F_MAGMA_CIPHER_CTL, GOST_R_UNSUPPORTED_CIPHER_CTL_COMMAND);
        return -1;
    }
    return 1;
}

static int magma_cipher_ctl_acpkm_omac(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr)
{
	switch (type)
	{
		case EVP_CTRL_PROCESS_UNPROTECTED:
		{
			struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
			STACK_OF(X509_ATTRIBUTE) *x = ptr;
      return gost2015_process_unprotected_attributes(x, arg, MAGMA_MAC_MAX_SIZE, c->tag);
		}
    case EVP_CTRL_COPY: {
			EVP_CIPHER_CTX *out = ptr;
      struct ossl_gost_cipher_ctx *in_cctx  = EVP_CIPHER_CTX_get_cipher_data(ctx);
      struct ossl_gost_cipher_ctx *out_cctx = EVP_CIPHER_CTX_get_cipher_data(out);

			if (in_cctx->omac_ctx == out_cctx->omac_ctx) {
				out_cctx->omac_ctx = EVP_MD_CTX_new();
				if (out_cctx->omac_ctx == NULL) {
					GOSTerr(GOST_F_MAGMA_CIPHER_CTL_ACPKM_OMAC, ERR_R_MALLOC_FAILURE);
					return -1;
				}
			}
			return EVP_MD_CTX_copy(out_cctx->omac_ctx, in_cctx->omac_ctx);
		}
		default:
			return magma_cipher_ctl(ctx, type, arg, ptr);
			break;
	}
}

/* Set cipher parameters from ASN1 structure */
static int gost89_set_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params)
{
    int len = 0;
    unsigned char *buf = NULL;
    unsigned char *p = NULL;
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    GOST_CIPHER_PARAMS *gcp = GOST_CIPHER_PARAMS_new();
    ASN1_OCTET_STRING *os = NULL;
    if (!gcp) {
        GOSTerr(GOST_F_GOST89_SET_ASN1_PARAMETERS, ERR_R_MALLOC_FAILURE);
        return 0;
    }
    if (!ASN1_OCTET_STRING_set
        (gcp->iv, EVP_CIPHER_CTX_iv(ctx), EVP_CIPHER_CTX_iv_length(ctx))) {
        GOST_CIPHER_PARAMS_free(gcp);
        GOSTerr(GOST_F_GOST89_SET_ASN1_PARAMETERS, ERR_R_MALLOC_FAILURE);
        return 0;
    }
    ASN1_OBJECT_free(gcp->enc_param_set);
    gcp->enc_param_set = OBJ_nid2obj(c->paramNID);

    len = i2d_GOST_CIPHER_PARAMS(gcp, NULL);
    p = buf = OPENSSL_malloc(len);
    if (!buf) {
        GOST_CIPHER_PARAMS_free(gcp);
        GOSTerr(GOST_F_GOST89_SET_ASN1_PARAMETERS, ERR_R_MALLOC_FAILURE);
        return 0;
    }
    i2d_GOST_CIPHER_PARAMS(gcp, &p);
    GOST_CIPHER_PARAMS_free(gcp);

    os = ASN1_OCTET_STRING_new();

    if (!os || !ASN1_OCTET_STRING_set(os, buf, len)) {
        OPENSSL_free(buf);
        GOSTerr(GOST_F_GOST89_SET_ASN1_PARAMETERS, ERR_R_MALLOC_FAILURE);
        return 0;
    }
    OPENSSL_free(buf);

    ASN1_TYPE_set(params, V_ASN1_SEQUENCE, os);
    return 1;
}

/* Store parameters into ASN1 structure */
static int gost89_get_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params)
{
    int len;
    GOST_CIPHER_PARAMS *gcp = NULL;
    unsigned char *p;
    struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
    int nid;

    if (ASN1_TYPE_get(params) != V_ASN1_SEQUENCE) {
        return -1;
    }

    p = params->value.sequence->data;

    gcp = d2i_GOST_CIPHER_PARAMS(NULL, (const unsigned char **)&p,
                                 params->value.sequence->length);

    len = gcp->iv->length;
    if (len != EVP_CIPHER_CTX_iv_length(ctx)) {
        GOST_CIPHER_PARAMS_free(gcp);
        GOSTerr(GOST_F_GOST89_GET_ASN1_PARAMETERS, GOST_R_INVALID_IV_LENGTH);
        return -1;
    }

    nid = OBJ_obj2nid(gcp->enc_param_set);
    if (nid == NID_undef) {
        GOST_CIPHER_PARAMS_free(gcp);
        GOSTerr(GOST_F_GOST89_GET_ASN1_PARAMETERS,
                GOST_R_INVALID_CIPHER_PARAM_OID);
        return -1;
    }

    if (!gost_cipher_set_param(c, nid)) {
        GOST_CIPHER_PARAMS_free(gcp);
        return -1;
    }
    /*XXX missing non-const accessor */
    memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), gcp->iv->data,
           EVP_CIPHER_CTX_iv_length(ctx));

    GOST_CIPHER_PARAMS_free(gcp);

    return 1;
}

#define MAGMA_UKM_LEN 12
static int magma_set_asn1_parameters (EVP_CIPHER_CTX *ctx, ASN1_TYPE *params)
{
  struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
	c->key_meshing = 8192;

	return gost2015_set_asn1_params(params, EVP_CIPHER_CTX_original_iv(ctx), 4,
		c->kdf_seed);
}

static int magma_get_asn1_parameters(EVP_CIPHER_CTX *ctx, ASN1_TYPE *params)
{
  struct ossl_gost_cipher_ctx *c = EVP_CIPHER_CTX_get_cipher_data(ctx);
	unsigned char iv[16];

	c->key_meshing = 8192;

	if (gost2015_get_asn1_params(params, MAGMA_UKM_LEN, iv, 4, c->kdf_seed) < 0)
	    return -1;

	memcpy(EVP_CIPHER_CTX_iv_noconst(ctx), iv, sizeof(iv));
	memcpy((unsigned char *)EVP_CIPHER_CTX_original_iv(ctx), iv, sizeof(iv));
	/* Key meshing 8 kb*/
	c->key_meshing = 8192;

	return 1;
}

static int gost_imit_init(EVP_MD_CTX *ctx, gost_subst_block * block)
{
    struct ossl_gost_imit_ctx *c = EVP_MD_CTX_md_data(ctx);
    memset(c->buffer, 0, sizeof(c->buffer));
    memset(c->partial_block, 0, sizeof(c->partial_block));
    c->count = 0;
    c->bytes_left = 0;
    c->key_meshing = 1;
    c->dgst_size = 4;
    gost_init(&(c->cctx), block);
    return 1;
}

static int gost_imit_init_cpa(EVP_MD_CTX *ctx)
{
    return gost_imit_init(ctx, &Gost28147_CryptoProParamSetA);
}

static int gost_imit_init_cp_12(EVP_MD_CTX *ctx)
{
    return gost_imit_init(ctx, &Gost28147_TC26ParamSetZ);
}

static void mac_block_mesh(struct ossl_gost_imit_ctx *c,
                           const unsigned char *data)
{
    /*
     * We are using NULL for iv because CryptoPro doesn't interpret
     * internal state of MAC algorithm as iv during keymeshing (but does
     * initialize internal state from iv in key transport
     */
    assert(c->count % 8 == 0 && c->count <= 1024);
    if (c->key_meshing && c->count == 1024) {
        cryptopro_key_meshing(&(c->cctx), NULL);
    }
    mac_block(&(c->cctx), c->buffer, data);
    c->count = c->count % 1024 + 8;
}

static int gost_imit_update(EVP_MD_CTX *ctx, const void *data, size_t count)
{
    struct ossl_gost_imit_ctx *c = EVP_MD_CTX_md_data(ctx);
    const unsigned char *p = data;
    size_t bytes = count;
    if (!(c->key_set)) {
        GOSTerr(GOST_F_GOST_IMIT_UPDATE, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }
    if (c->bytes_left) {
        size_t i;
        for (i = c->bytes_left; i < 8 && bytes > 0; bytes--, i++, p++) {
            c->partial_block[i] = *p;
        }
        if (i == 8) {
            mac_block_mesh(c, c->partial_block);
        } else {
            c->bytes_left = i;
            return 1;
        }
    }
    while (bytes > 8) {
        mac_block_mesh(c, p);
        p += 8;
        bytes -= 8;
    }
    if (bytes > 0) {
        memcpy(c->partial_block, p, bytes);
    }
    c->bytes_left = bytes;
    return 1;
}

static int gost_imit_final(EVP_MD_CTX *ctx, unsigned char *md)
{
    struct ossl_gost_imit_ctx *c = EVP_MD_CTX_md_data(ctx);
    if (!c->key_set) {
        GOSTerr(GOST_F_GOST_IMIT_FINAL, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }
    if (c->count == 0 && c->bytes_left) {
        unsigned char buffer[8];
        memset(buffer, 0, 8);
        gost_imit_update(ctx, buffer, 8);
    }
    if (c->bytes_left) {
        int i;
        for (i = c->bytes_left; i < 8; i++) {
            c->partial_block[i] = 0;
        }
        mac_block_mesh(c, c->partial_block);
    }
    get_mac(c->buffer, 8 * c->dgst_size, md);
    return 1;
}

static int gost_imit_ctrl(EVP_MD_CTX *ctx, int type, int arg, void *ptr)
{
    switch (type) {
    case EVP_MD_CTRL_KEY_LEN:
        *((unsigned int *)(ptr)) = 32;
        return 1;
    case EVP_MD_CTRL_SET_KEY:
        {
            struct ossl_gost_imit_ctx *gost_imit_ctx = EVP_MD_CTX_md_data(ctx);

            if (EVP_MD_meth_get_init(EVP_MD_CTX_md(ctx)) (ctx) <= 0) {
                GOSTerr(GOST_F_GOST_IMIT_CTRL, GOST_R_MAC_KEY_NOT_SET);
                return 0;
            }
            EVP_MD_CTX_set_flags(ctx, EVP_MD_CTX_FLAG_NO_INIT);

            if (arg == 0) {
                struct gost_mac_key *key = (struct gost_mac_key *)ptr;
                if (key->mac_param_nid != NID_undef) {
                    const struct gost_cipher_info *param =
                        get_encryption_params(OBJ_nid2obj(key->mac_param_nid));
                    if (param == NULL) {
                        GOSTerr(GOST_F_GOST_IMIT_CTRL,
                                GOST_R_INVALID_MAC_PARAMS);
                        return 0;
                    }
                    gost_init(&(gost_imit_ctx->cctx), param->sblock);
                }
                gost_key(&(gost_imit_ctx->cctx), key->key);
                gost_imit_ctx->key_set = 1;

                return 1;
            } else if (arg == 32) {
                gost_key(&(gost_imit_ctx->cctx), ptr);
                gost_imit_ctx->key_set = 1;
                return 1;
            }
            GOSTerr(GOST_F_GOST_IMIT_CTRL, GOST_R_INVALID_MAC_KEY_SIZE);
            return 0;
        }
    case EVP_MD_CTRL_XOF_LEN:
        {
            struct ossl_gost_imit_ctx *c = EVP_MD_CTX_md_data(ctx);
            if (arg < 1 || arg > 8) {
                GOSTerr(GOST_F_GOST_IMIT_CTRL, GOST_R_INVALID_MAC_SIZE);
                return 0;
            }
            c->dgst_size = arg;
            return 1;
        }

    default:
        return 0;
    }
}

static int gost_imit_copy(EVP_MD_CTX *to, const EVP_MD_CTX *from)
{
    if (EVP_MD_CTX_md_data(to) && EVP_MD_CTX_md_data(from)) {
        memcpy(EVP_MD_CTX_md_data(to), EVP_MD_CTX_md_data(from),
               sizeof(struct ossl_gost_imit_ctx));
    }
    return 1;
}

/* Clean up imit ctx */
static int gost_imit_cleanup(EVP_MD_CTX *ctx)
{
    memset(EVP_MD_CTX_md_data(ctx), 0, sizeof(struct ossl_gost_imit_ctx));
    return 1;
}
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
