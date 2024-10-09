/**********************************************************************
 *             gost_prov_digest.c - Initialize all digests            *
 *                                                                    *
 *      Copyright (c) 2021 Richard Levitte <richard@levitte.org>      *
 *     This file is distributed under the same license as OpenSSL     *
 *                                                                    *
 *         OpenSSL provider interface to GOST digest functions        *
 *                Requires OpenSSL 3.0 for compilation                *
 **********************************************************************/

#include <openssl/core.h>
#include <openssl/core_dispatch.h>
#include "gost_prov.h"
#include "gost_lcl.h"

/*
 * Forward declarations of all OSSL_DISPATCH functions, to make sure they
 * are correctly defined further down.
 */
static OSSL_FUNC_digest_dupctx_fn digest_dupctx;
static OSSL_FUNC_digest_freectx_fn digest_freectx;
static OSSL_FUNC_digest_init_fn digest_init;
static OSSL_FUNC_digest_update_fn digest_update;
static OSSL_FUNC_digest_final_fn digest_final;


struct gost_prov_crypt_ctx_st {
    /* Provider context */
    PROV_CTX *provctx;
    /* OSSL_PARAM descriptors */
    const OSSL_PARAM *known_params;
    /* GOST_digest descriptor */
    GOST_digest *descriptor;

    /*
     * Since existing functionality is designed for ENGINEs, the functions
     * in this file are accomodated and are simply wrappers that use a local
     * EVP_MD and EVP_MD_CTX.
     * Future development should take a more direct approach and have the
     * appropriate digest functions and digest data directly in this context.
     */

    /* The EVP_MD created from |descriptor| */
    EVP_MD *digest;
    /* The context for the EVP_MD functions */
    EVP_MD_CTX *dctx;
};
typedef struct gost_prov_crypt_ctx_st GOST_CTX;

static void digest_freectx(void *vgctx)
{
    GOST_CTX *gctx = vgctx;

    /*
     * We don't free gctx->digest here.
     * That will be done by the provider teardown, via
     * GOST_prov_deinit_digests() (defined at the bottom of this file).
     */
    EVP_MD_CTX_free(gctx->dctx);
    OPENSSL_free(gctx);
}

static GOST_CTX *digest_newctx(void *provctx, GOST_digest *descriptor,
                               const OSSL_PARAM *known_params)
{
    GOST_CTX *gctx = NULL;

    if ((gctx = OPENSSL_zalloc(sizeof(*gctx))) != NULL) {
        gctx->provctx = provctx;
        gctx->known_params = known_params;
        gctx->descriptor = descriptor;
        gctx->digest = GOST_init_digest(descriptor);
        gctx->dctx = EVP_MD_CTX_new();

        if (gctx->digest == NULL || gctx->dctx == NULL) {
            digest_freectx(gctx);
            gctx = NULL;
        }
    }
    return gctx;
}

static void *digest_dupctx(void *vsrc)
{
    GOST_CTX *src = vsrc;
    GOST_CTX *dst =
        digest_newctx(src->provctx, src->descriptor, src->known_params);

    if (dst != NULL)
        EVP_MD_CTX_copy(dst->dctx, src->dctx);
    return dst;
}

static int digest_get_params(EVP_MD *d, OSSL_PARAM params[])
{
    OSSL_PARAM *p;

    if (((p = OSSL_PARAM_locate(params, "blocksize")) != NULL
         && !OSSL_PARAM_set_size_t(p, EVP_MD_block_size(d)))
        || ((p = OSSL_PARAM_locate(params, "size")) != NULL
            && !OSSL_PARAM_set_size_t(p, EVP_MD_size(d)))
        || ((p = OSSL_PARAM_locate(params, "xof")) != NULL
            && !OSSL_PARAM_set_size_t(p, EVP_MD_flags(d) & EVP_MD_FLAG_XOF)))
        return 0;
    return 1;
}

static int digest_init(void *vgctx, const OSSL_PARAM unused_params[])
{
    GOST_CTX *gctx = vgctx;

    return EVP_DigestInit_ex(gctx->dctx, gctx->digest, gctx->provctx->e) > 0;
}

static int digest_update(void *vgctx, const unsigned char *in, size_t inl)
{
    GOST_CTX *gctx = vgctx;

    return EVP_DigestUpdate(gctx->dctx, in, (int)inl) > 0;
}

static int digest_final(void *vgctx,
                        unsigned char *out, size_t *outl, size_t outsize)
{
    GOST_CTX *gctx = vgctx;
    unsigned int int_outl = outl != NULL ? *outl : 0;
    int res = EVP_DigestFinal(gctx->dctx, out, &int_outl);

    if (res > 0 && outl != NULL)
        *outl = (size_t)int_outl;
    return res > 0;
}

static const OSSL_PARAM *known_GostR3411_94_digest_params;
static const OSSL_PARAM *known_GostR3411_2012_256_digest_params;
static const OSSL_PARAM *known_GostR3411_2012_512_digest_params;

/*
 * These are named like the EVP_MD templates in gost_md.c etc, with the
 * added suffix "_functions".  Hopefully, that makes it easy to find the
 * actual implementation.
 */
typedef void (*fptr_t)(void);
#define MAKE_FUNCTIONS(name)                                            \
    static OSSL_FUNC_digest_get_params_fn name##_get_params;            \
    static int name##_get_params(OSSL_PARAM *params)                    \
    {                                                                   \
        return digest_get_params(GOST_init_digest(&name), params);      \
    }                                                                   \
    static OSSL_FUNC_digest_newctx_fn name##_newctx;                    \
    static void *name##_newctx(void *provctx)                           \
    {                                                                   \
        return digest_newctx(provctx, &name, known_##name##_params);    \
    }                                                                   \
    static const OSSL_DISPATCH name##_functions[] = {                   \
        { OSSL_FUNC_DIGEST_GET_PARAMS, (fptr_t)name##_get_params },     \
        { OSSL_FUNC_DIGEST_NEWCTX, (fptr_t)name##_newctx },             \
        { OSSL_FUNC_DIGEST_DUPCTX, (fptr_t)digest_dupctx },             \
        { OSSL_FUNC_DIGEST_FREECTX, (fptr_t)digest_freectx },           \
        { OSSL_FUNC_DIGEST_INIT, (fptr_t)digest_init },                 \
        { OSSL_FUNC_DIGEST_UPDATE, (fptr_t)digest_update },             \
        { OSSL_FUNC_DIGEST_FINAL, (fptr_t)digest_final },               \
    }

MAKE_FUNCTIONS(GostR3411_94_digest);
MAKE_FUNCTIONS(GostR3411_2012_256_digest);
MAKE_FUNCTIONS(GostR3411_2012_512_digest);

/* The OSSL_ALGORITHM for the provider's operation query function */
const OSSL_ALGORITHM GOST_prov_digests[] = {
    /*
     * Described in RFC 6986, first name from
     * https://www.ietf.org/archive/id/draft-deremin-rfc4491-bis-06.txt
     * (is there not an RFC namming these?)
     */
    { "id-tc26-gost3411-12-256:md_gost12_256:1.2.643.7.1.1.2.2", NULL,
      GostR3411_2012_256_digest_functions,
      "GOST R 34.11-2012 with 256 bit hash" },
    { "id-tc26-gost3411-12-512:md_gost12_512:1.2.643.7.1.1.2.3", NULL,
      GostR3411_2012_512_digest_functions,
      "GOST R 34.11-2012 with 512 bit hash" },

    /* Described in RFC 5831, first name from RFC 4357, section 10.4 */
    { "id-GostR3411-94:md_gost94:1.2.643.2.2.9", NULL,
      GostR3411_94_digest_functions, "GOST R 34.11-94" },
    { NULL , NULL, NULL }
};

void GOST_prov_deinit_digests(void) {
    static GOST_digest *list[] = {
        &GostR3411_94_digest,
        &GostR3411_2012_256_digest,
        &GostR3411_2012_512_digest,
    };
    size_t i;
#define elems(l) (sizeof(l) / sizeof(l[0]))

    for (i = 0; i < elems(list); i++)
        GOST_deinit_digest(list[i]);
}
