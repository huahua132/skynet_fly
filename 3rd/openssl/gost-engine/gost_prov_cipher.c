/**********************************************************************
 *             gost_prov_crypt.c - Initialize all ciphers             *
 *                                                                    *
 *      Copyright (c) 2021 Richard Levitte <richard@levitte.org>      *
 *     This file is distributed under the same license as OpenSSL     *
 *                                                                    *
 *         OpenSSL provider interface to GOST cipher functions        *
 *                Requires OpenSSL 3.0 for compilation                *
 **********************************************************************/

#include <openssl/core.h>
#include <openssl/core_dispatch.h>
#include <openssl/core_names.h>
#include "gost_prov.h"
#include "gost_lcl.h"

/*
 * Forward declarations of all generic OSSL_DISPATCH functions, to make sure
 * they are correctly defined further down.  For the algorithm specific ones
 * MAKE_FUNCTIONS() does it for us.
 */
static OSSL_FUNC_cipher_dupctx_fn cipher_dupctx;
static OSSL_FUNC_cipher_freectx_fn cipher_freectx;
static OSSL_FUNC_cipher_get_ctx_params_fn cipher_get_ctx_params;
static OSSL_FUNC_cipher_set_ctx_params_fn cipher_set_ctx_params;
static OSSL_FUNC_cipher_encrypt_init_fn cipher_encrypt_init;
static OSSL_FUNC_cipher_decrypt_init_fn cipher_decrypt_init;
static OSSL_FUNC_cipher_update_fn cipher_update;
static OSSL_FUNC_cipher_final_fn cipher_final;

struct gost_prov_crypt_ctx_st {
    /* Provider context */
    PROV_CTX *provctx;
    /* OSSL_PARAM descriptors */
    const OSSL_PARAM *known_params;
    /* GOST_cipher descriptor */
    GOST_cipher *descriptor;

    /*
     * Since existing functionality is designed for ENGINEs, the functions
     * in this file are accomodated and are simply wrappers that use a local
     * EVP_CIPHER and EVP_CIPHER_CTX.
     * Future development should take a more direct approach and have the
     * appropriate cipher functions and cipher data directly in this context.
     */

    /* The EVP_CIPHER created from |descriptor| */
    EVP_CIPHER *cipher;
    /* The context for the EVP_CIPHER functions */
    EVP_CIPHER_CTX *cctx;
};
typedef struct gost_prov_crypt_ctx_st GOST_CTX;

static void cipher_freectx(void *vgctx)
{
    GOST_CTX *gctx = vgctx;

    /*
     * We don't free gctx->cipher here.
     * That will be done by the provider teardown, via
     * GOST_prov_deinit_ciphers() (defined at the bottom of this file).
     */
    EVP_CIPHER_CTX_free(gctx->cctx);
    OPENSSL_free(gctx);
}

static GOST_CTX *cipher_newctx(void *provctx, GOST_cipher *descriptor,
                                const OSSL_PARAM *known_params)
{
    GOST_CTX *gctx = NULL;

    if ((gctx = OPENSSL_zalloc(sizeof(*gctx))) != NULL) {
        gctx->provctx = provctx;
        gctx->known_params = known_params;
        gctx->descriptor = descriptor;
        gctx->cipher = GOST_init_cipher(descriptor);
        gctx->cctx = EVP_CIPHER_CTX_new();

        if (gctx->cipher == NULL || gctx->cctx == NULL) {
            cipher_freectx(gctx);
            gctx = NULL;
        }
    }
    return gctx;
}

static void *cipher_dupctx(void *vsrc)
{
    GOST_CTX *src = vsrc;
    GOST_CTX *dst =
        cipher_newctx(src->provctx, src->descriptor, src->known_params);

    if (dst != NULL)
        EVP_CIPHER_CTX_copy(dst->cctx, src->cctx);
    return dst;
}

static int cipher_get_params(EVP_CIPHER *c, OSSL_PARAM params[])
{
    OSSL_PARAM *p;

    if (((p = OSSL_PARAM_locate(params, "blocksize")) != NULL
         && !OSSL_PARAM_set_size_t(p, EVP_CIPHER_block_size(c)))
        || ((p = OSSL_PARAM_locate(params, "ivlen")) != NULL
            && !OSSL_PARAM_set_size_t(p, EVP_CIPHER_iv_length(c)))
        || ((p = OSSL_PARAM_locate(params, "keylen")) != NULL
            && !OSSL_PARAM_set_size_t(p, EVP_CIPHER_key_length(c)))
        || ((p = OSSL_PARAM_locate(params, "mode")) != NULL
            && !OSSL_PARAM_set_size_t(p, EVP_CIPHER_flags(c))))
        return 0;
    return 1;
}

static int cipher_get_ctx_params(void *vgctx, OSSL_PARAM params[])
{
    GOST_CTX *gctx = vgctx;
    OSSL_PARAM *p;

    if (!cipher_get_params(gctx->cipher, params))
        return 0;
    if ((p = OSSL_PARAM_locate(params, "alg_id_param")) != NULL) {
        ASN1_TYPE *algidparam = NULL;
        unsigned char *der = NULL;
        int derlen = 0;
        int ret;

        ret = (algidparam = ASN1_TYPE_new()) != NULL
            && EVP_CIPHER_param_to_asn1(gctx->cctx, algidparam) > 0
            && (derlen = i2d_ASN1_TYPE(algidparam, &der)) >= 0
            && OSSL_PARAM_set_octet_string(p, &der, (size_t)derlen);

        OPENSSL_free(der);
        ASN1_TYPE_free(algidparam);
        return ret;
    }
    if ((p = OSSL_PARAM_locate(params, "updated-iv")) != NULL) {
        const void *iv = EVP_CIPHER_CTX_iv(gctx->cctx);
        size_t ivlen = EVP_CIPHER_CTX_iv_length(gctx->cctx);

        if (!OSSL_PARAM_set_octet_ptr(p, iv, ivlen)
            && !OSSL_PARAM_set_octet_string(p, iv, ivlen))
            return 0;
    }
    if ((p = OSSL_PARAM_locate(params, OSSL_CIPHER_PARAM_AEAD_TAG)) != NULL) {
        void *tag = NULL;
        size_t taglen = 0;

        if (!OSSL_PARAM_get_octet_string_ptr(p, (const void**)&tag, &taglen)
            || EVP_CIPHER_CTX_ctrl(gctx->cctx, EVP_CTRL_AEAD_GET_TAG,
                                   taglen, tag) <= 0)
            return 0;
    }
    return 1;
}

static int cipher_set_ctx_params(void *vgctx, const OSSL_PARAM params[])
{
    GOST_CTX *gctx = vgctx;
    const OSSL_PARAM *p;

    if ((p = OSSL_PARAM_locate_const(params, "alg_id_param")) != NULL) {
        ASN1_TYPE *algidparam = NULL;
        const unsigned char *der = NULL;
        size_t derlen = 0;
        int ret;

        ret = OSSL_PARAM_get_octet_string_ptr(p, (const void **)&der, &derlen)
            && (algidparam = d2i_ASN1_TYPE(NULL, &der, (long)derlen)) != NULL
            && EVP_CIPHER_asn1_to_param(gctx->cctx, algidparam) > 0;

        ASN1_TYPE_free(algidparam);
        return ret;
    }
    if ((p = OSSL_PARAM_locate_const(params, "padding")) != NULL) {
        unsigned int pad = 0;

        if (!OSSL_PARAM_get_uint(p, &pad)
            || EVP_CIPHER_CTX_set_padding(gctx->cctx, pad) <= 0)
            return 0;
    }
    if ((p = OSSL_PARAM_locate_const(params, "key-mesh")) != NULL) {
        size_t key_mesh = 0;

        if (!OSSL_PARAM_get_size_t(p, &key_mesh)
            || EVP_CIPHER_CTX_ctrl(gctx->cctx, EVP_CTRL_KEY_MESH,
                                   key_mesh, NULL) <= 0)
            return 0;
    }
    if ((p = OSSL_PARAM_locate_const(params, OSSL_CIPHER_PARAM_IVLEN)) != NULL) {
        size_t ivlen = 0;

        if (!OSSL_PARAM_get_size_t(p, &ivlen)
            || EVP_CIPHER_CTX_ctrl(gctx->cctx, EVP_CTRL_AEAD_SET_IVLEN,
                                   ivlen, NULL) <= 0)
            return 0;
    }
    if ((p = OSSL_PARAM_locate_const(params, OSSL_CIPHER_PARAM_AEAD_TAG)) != NULL) {
        char tag[1024];
        void *val = (void *) tag;
        size_t taglen = 0;

        if (!OSSL_PARAM_get_octet_string(p, &val, 1024, &taglen)
            || EVP_CIPHER_CTX_ctrl(gctx->cctx, EVP_CTRL_AEAD_SET_TAG,
                                   taglen, &tag) <= 0)
            return 0;
    }
    return 1;
}

static int cipher_encrypt_init(void *vgctx,
                               const unsigned char *key, size_t keylen,
                               const unsigned char *iv, size_t ivlen,
                               const OSSL_PARAM params[])
{
    GOST_CTX *gctx = vgctx;

    if (!cipher_set_ctx_params(vgctx, params)
        || keylen > EVP_CIPHER_key_length(gctx->cipher)
        || ivlen > EVP_CIPHER_iv_length(gctx->cipher))
        return 0;

    return EVP_CipherInit_ex(gctx->cctx, gctx->cipher, gctx->provctx->e,
                             key, iv, 1);
}

static int cipher_decrypt_init(void *vgctx,
                               const unsigned char *key, size_t keylen,
                               const unsigned char *iv, size_t ivlen,
                               const OSSL_PARAM params[])
{
    GOST_CTX *gctx = vgctx;

    if (!cipher_set_ctx_params(vgctx, params)
        || keylen > EVP_CIPHER_key_length(gctx->cipher)
        || ivlen > EVP_CIPHER_iv_length(gctx->cipher))
        return 0;
    return EVP_CipherInit_ex(gctx->cctx, gctx->cipher, gctx->provctx->e,
                             key, iv, 0) > 0;
}

static int cipher_update(void *vgctx,
                         unsigned char *out, size_t *outl, size_t outsize,
                         const unsigned char *in, size_t inl)
{
    GOST_CTX *gctx = vgctx;
    int int_outl = outl != NULL ? *outl : 0;
    int res = EVP_CipherUpdate(gctx->cctx, out, &int_outl, in, (int)inl);

    if (res > 0 && outl != NULL)
        *outl = (size_t)int_outl;
    return res > 0;
}

static int cipher_final(void *vgctx,
                        unsigned char *out, size_t *outl, size_t outsize)
{
    GOST_CTX *gctx = vgctx;
    int int_outl = outl != NULL ? *outl : 0;
    int res = EVP_CipherFinal(gctx->cctx, out, &int_outl);

    if (res > 0 && outl != NULL)
        *outl = (size_t)int_outl;
    return res > 0;
}

static const OSSL_PARAM *known_Gost28147_89_cipher_params;
static const OSSL_PARAM *known_Gost28147_89_cbc_cipher_params;
static const OSSL_PARAM *known_Gost28147_89_cnt_cipher_params;
static const OSSL_PARAM *known_Gost28147_89_cnt_12_cipher_params;
static const OSSL_PARAM *known_grasshopper_ecb_cipher_params;
static const OSSL_PARAM *known_grasshopper_cbc_cipher_params;
static const OSSL_PARAM *known_grasshopper_cfb_cipher_params;
static const OSSL_PARAM *known_grasshopper_ofb_cipher_params;
static const OSSL_PARAM *known_grasshopper_ctr_cipher_params;
static const OSSL_PARAM *known_magma_ctr_cipher_params;
static const OSSL_PARAM *known_magma_ctr_acpkm_cipher_params;
static const OSSL_PARAM *known_magma_ctr_acpkm_omac_cipher_params;
static const OSSL_PARAM *known_magma_cbc_cipher_params;
static const OSSL_PARAM *known_magma_mgm_cipher_params;
static const OSSL_PARAM *known_grasshopper_ctr_acpkm_cipher_params;
static const OSSL_PARAM *known_grasshopper_ctr_acpkm_omac_cipher_params;
static const OSSL_PARAM *known_grasshopper_mgm_cipher_params;
/*
 * These are named like the EVP_CIPHER templates in gost_crypt.c, with the
 * added suffix "_functions".  Hopefully, that makes it easy to find the
 * actual implementation.
 */
typedef void (*fptr_t)(void);
#define MAKE_FUNCTIONS(name)                                            \
    static OSSL_FUNC_cipher_get_params_fn name##_get_params;            \
    static int name##_get_params(OSSL_PARAM *params)                    \
    {                                                                   \
        return cipher_get_params(GOST_init_cipher(&name), params);      \
    }                                                                   \
    static OSSL_FUNC_cipher_newctx_fn name##_newctx;                    \
    static void *name##_newctx(void *provctx)                           \
    {                                                                   \
        return cipher_newctx(provctx, &name, known_##name##_params);    \
    }                                                                   \
    static const OSSL_DISPATCH name##_functions[] = {                   \
        { OSSL_FUNC_CIPHER_GET_PARAMS, (fptr_t)name##_get_params },     \
        { OSSL_FUNC_CIPHER_NEWCTX, (fptr_t)name##_newctx },             \
        { OSSL_FUNC_CIPHER_DUPCTX, (fptr_t)cipher_dupctx },             \
        { OSSL_FUNC_CIPHER_FREECTX, (fptr_t)cipher_freectx },           \
        { OSSL_FUNC_CIPHER_GET_CTX_PARAMS, (fptr_t)cipher_get_ctx_params }, \
        { OSSL_FUNC_CIPHER_SET_CTX_PARAMS, (fptr_t)cipher_set_ctx_params }, \
        { OSSL_FUNC_CIPHER_ENCRYPT_INIT, (fptr_t)cipher_encrypt_init }, \
        { OSSL_FUNC_CIPHER_DECRYPT_INIT, (fptr_t)cipher_decrypt_init }, \
        { OSSL_FUNC_CIPHER_UPDATE, (fptr_t)cipher_update },             \
        { OSSL_FUNC_CIPHER_FINAL, (fptr_t)cipher_final },               \
        { 0, NULL },                                                    \
    }

MAKE_FUNCTIONS(Gost28147_89_cipher);
MAKE_FUNCTIONS(Gost28147_89_cnt_cipher);
MAKE_FUNCTIONS(Gost28147_89_cnt_12_cipher);
MAKE_FUNCTIONS(Gost28147_89_cbc_cipher);
MAKE_FUNCTIONS(grasshopper_ecb_cipher);
MAKE_FUNCTIONS(grasshopper_cbc_cipher);
MAKE_FUNCTIONS(grasshopper_cfb_cipher);
MAKE_FUNCTIONS(grasshopper_ofb_cipher);
MAKE_FUNCTIONS(grasshopper_ctr_cipher);
MAKE_FUNCTIONS(magma_cbc_cipher);
MAKE_FUNCTIONS(magma_ctr_cipher);
MAKE_FUNCTIONS(magma_ctr_acpkm_cipher);
MAKE_FUNCTIONS(magma_ctr_acpkm_omac_cipher);
MAKE_FUNCTIONS(magma_mgm_cipher);
MAKE_FUNCTIONS(grasshopper_ctr_acpkm_cipher);
MAKE_FUNCTIONS(grasshopper_ctr_acpkm_omac_cipher);
MAKE_FUNCTIONS(grasshopper_mgm_cipher);

/* The OSSL_ALGORITHM for the provider's operation query function */
const OSSL_ALGORITHM GOST_prov_ciphers[] = {
    { SN_id_Gost28147_89 ":gost89:GOST 28147-89:1.2.643.2.2.21", NULL,
      Gost28147_89_cipher_functions },
    { SN_gost89_cnt, NULL, Gost28147_89_cnt_cipher_functions },
    { SN_gost89_cnt_12, NULL, Gost28147_89_cnt_12_cipher_functions },
    { SN_gost89_cbc, NULL, Gost28147_89_cbc_cipher_functions },
    { SN_grasshopper_ecb, NULL, grasshopper_ecb_cipher_functions },
    { SN_grasshopper_cbc, NULL, grasshopper_cbc_cipher_functions },
    { SN_grasshopper_cfb, NULL, grasshopper_cfb_cipher_functions },
    { SN_grasshopper_ofb, NULL, grasshopper_ofb_cipher_functions },
    { SN_grasshopper_ctr, NULL, grasshopper_ctr_cipher_functions },
    { SN_magma_cbc, NULL, magma_cbc_cipher_functions },
    { SN_magma_ctr, NULL, magma_ctr_cipher_functions },
    { SN_magma_ctr_acpkm ":1.2.643.7.1.1.5.1.1", NULL,
      magma_ctr_acpkm_cipher_functions },
    { SN_magma_ctr_acpkm_omac ":1.2.643.7.1.1.5.1.2", NULL,
      magma_ctr_acpkm_omac_cipher_functions },
    { "magma-mgm", NULL, magma_mgm_cipher_functions },
    { SN_kuznyechik_ctr_acpkm ":1.2.643.7.1.1.5.2.1", NULL,
      grasshopper_ctr_acpkm_cipher_functions },
    { SN_kuznyechik_ctr_acpkm_omac ":1.2.643.7.1.1.5.2.2", NULL,
      grasshopper_ctr_acpkm_omac_cipher_functions },
    { "kuznyechik-mgm", NULL, grasshopper_mgm_cipher_functions },
#if 0                           /* Not yet implemented */
    { SN_magma_kexp15 ":1.2.643.7.1.1.7.1.1", NULL,
      magma_kexp15_cipher_functions },
    { SN_kuznyechik_kexp15 ":1.2.643.7.1.1.7.2.1", NULL,
      kuznyechik_kexp15_cipher_functions },
#endif
    { NULL , NULL, NULL }
};

void GOST_prov_deinit_ciphers(void) {
    static GOST_cipher *list[] = {
        &Gost28147_89_cipher,
        &Gost28147_89_cnt_cipher,
        &Gost28147_89_cnt_12_cipher,
        &Gost28147_89_cbc_cipher,
        &grasshopper_ecb_cipher,
        &grasshopper_cbc_cipher,
        &grasshopper_cfb_cipher,
        &grasshopper_ofb_cipher,
        &grasshopper_ctr_cipher,
        &magma_cbc_cipher,
        &magma_ctr_cipher,
        &magma_ctr_acpkm_cipher,
        &magma_ctr_acpkm_omac_cipher,
        &magma_mgm_cipher,
        &grasshopper_ctr_acpkm_cipher,
        &grasshopper_ctr_acpkm_omac_cipher,
        &grasshopper_mgm_cipher,
    };
    size_t i;
#define elems(l) (sizeof(l) / sizeof(l[0]))

    for (i = 0; i < elems(list); i++)
        GOST_deinit_cipher(list[i]);
}
