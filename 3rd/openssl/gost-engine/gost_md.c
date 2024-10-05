/**********************************************************************
 *                          md_gost.c                                 *
 *             Copyright (c) 2005-2006 Cryptocom LTD                  *
 *             Copyright (c) 2020 Vitaly Chikunov <vt@altlinux.org>   *
 *         This file is distributed under the same license as OpenSSL *
 *                                                                    *
 *       OpenSSL interface to GOST R 34.11-94 hash functions          *
 *          Requires OpenSSL 0.9.9 for compilation                    *
 **********************************************************************/
#include <string.h>
#include "gost_lcl.h"
#include "gosthash.h"
#include "e_gost_err.h"

/* implementation of GOST 34.11 hash function See gost_md.c*/
static int gost_digest_init(EVP_MD_CTX *ctx);
static int gost_digest_update(EVP_MD_CTX *ctx, const void *data,
                              size_t count);
static int gost_digest_final(EVP_MD_CTX *ctx, unsigned char *md);
static int gost_digest_copy(EVP_MD_CTX *to, const EVP_MD_CTX *from);
static int gost_digest_cleanup(EVP_MD_CTX *ctx);

GOST_digest GostR3411_94_digest = {
    .nid = NID_id_GostR3411_94,
    .result_size = 32,
    .input_blocksize = 32,
    .app_datasize = sizeof(struct ossl_gost_digest_ctx),
    .init = gost_digest_init,
    .update = gost_digest_update,
    .final = gost_digest_final,
    .copy = gost_digest_copy,
    .cleanup = gost_digest_cleanup,
};

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

EVP_MD *GOST_init_digest(GOST_digest *d)
{
    if (d->digest)
        return d->digest;

    EVP_MD *md;
    if (!(md = EVP_MD_meth_new(d->nid, NID_undef))
        || !EVP_MD_meth_set_result_size(md, TPL(d, result_size))
        || !EVP_MD_meth_set_input_blocksize(md, TPL(d, input_blocksize))
        || !EVP_MD_meth_set_app_datasize(md, TPL(d, app_datasize))
        || !EVP_MD_meth_set_flags(md, d->flags | TPL_VAL(d, flags))
        || !EVP_MD_meth_set_init(md, TPL(d, init))
        || !EVP_MD_meth_set_update(md, TPL(d, update))
        || !EVP_MD_meth_set_final(md, TPL(d, final))
        || !EVP_MD_meth_set_copy(md, TPL(d, copy))
        || !EVP_MD_meth_set_cleanup(md, TPL(d, cleanup))
        || !EVP_MD_meth_set_ctrl(md, TPL(d, ctrl))) {
        EVP_MD_meth_free(md);
        md = NULL;
    }
    if (md && d->alias)
        EVP_add_digest_alias(EVP_MD_name(md), d->alias);
    d->digest = md;
    return md;
}

void GOST_deinit_digest(GOST_digest *d)
{
    if (d->alias)
        EVP_delete_digest_alias(d->alias);
    EVP_MD_meth_free(d->digest);
    d->digest = NULL;
}

static int gost_digest_init(EVP_MD_CTX *ctx)
{
    struct ossl_gost_digest_ctx *c = EVP_MD_CTX_md_data(ctx);
    memset(&(c->dctx), 0, sizeof(gost_hash_ctx));
    gost_init(&(c->cctx), &GostR3411_94_CryptoProParamSet);
    c->dctx.cipher_ctx = &(c->cctx);
    return 1;
}

static int gost_digest_update(EVP_MD_CTX *ctx, const void *data, size_t count)
{
    return hash_block((gost_hash_ctx *) EVP_MD_CTX_md_data(ctx), data, count);
}

static int gost_digest_final(EVP_MD_CTX *ctx, unsigned char *md)
{
    return finish_hash((gost_hash_ctx *) EVP_MD_CTX_md_data(ctx), md);

}

static int gost_digest_copy(EVP_MD_CTX *to, const EVP_MD_CTX *from)
{
    struct ossl_gost_digest_ctx *md_ctx = EVP_MD_CTX_md_data(to);
    if (EVP_MD_CTX_md_data(to) && EVP_MD_CTX_md_data(from)) {
        memcpy(EVP_MD_CTX_md_data(to), EVP_MD_CTX_md_data(from),
               sizeof(struct ossl_gost_digest_ctx));
        md_ctx->dctx.cipher_ctx = &(md_ctx->cctx);
    }
    return 1;
}

static int gost_digest_cleanup(EVP_MD_CTX *ctx)
{
    if (EVP_MD_CTX_md_data(ctx))
        memset(EVP_MD_CTX_md_data(ctx), 0,
               sizeof(struct ossl_gost_digest_ctx));
    return 1;
}
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
