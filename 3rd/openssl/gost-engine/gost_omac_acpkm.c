/*
 * Copyright (C) 2018,2020 Vitaly Chikunov <vt@altlinux.org>. All Rights Reserved.
 * Copyright (c) 2010 The OpenSSL Project.  All rights reserved.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */
#include <string.h>
#include <openssl/cmac.h>
#include <openssl/conf.h>
#include <openssl/err.h>
#include <openssl/evp.h>

#include "e_gost_err.h"
#include "gost_lcl.h"
#include "gost_grasshopper_defines.h"
#include "gost_grasshopper_cipher.h"

#define ACPKM_T_MAX (GRASSHOPPER_KEY_SIZE + GRASSHOPPER_BLOCK_SIZE)
/*
 * CMAC code from crypto/cmac/cmac.c with ACPKM tweaks
 */
struct CMAC_ACPKM_CTX_st {
    /* Cipher context to use */
    EVP_CIPHER_CTX *cctx;
    /* CTR-ACPKM cipher */
    EVP_CIPHER_CTX *actx;
    unsigned char km[ACPKM_T_MAX]; /* Key material */
    /* Temporary block */
    unsigned char tbl[EVP_MAX_BLOCK_LENGTH];
    /* Last (possibly partial) block */
    unsigned char last_block[EVP_MAX_BLOCK_LENGTH];
    /* Number of bytes in last block: -1 means context not initialised */
    int nlast_block;
    unsigned int section_size; /* N */
    unsigned int num; /* processed bytes until section_size */
};
typedef struct CMAC_ACPKM_CTX_st CMAC_ACPKM_CTX;

static unsigned char zero_iv[ACPKM_T_MAX];

/* Make temporary keys K1 and K2 */

static void make_kn(unsigned char *k1, unsigned char *l, int bl)
{
    int i;
    /* Shift block to left, including carry */
    for (i = 0; i < bl; i++) {
        k1[i] = l[i] << 1;
        if (i < bl - 1 && l[i + 1] & 0x80)
            k1[i] |= 1;
    }
    /* If MSB set fixup with R */
    if (l[0] & 0x80)
        k1[bl - 1] ^= bl == 16 ? 0x87 : 0x1b;
}

static CMAC_ACPKM_CTX *CMAC_ACPKM_CTX_new(void)
{
    CMAC_ACPKM_CTX *ctx;
    ctx = OPENSSL_zalloc(sizeof(CMAC_ACPKM_CTX));
    if (!ctx)
        return NULL;
    ctx->cctx = EVP_CIPHER_CTX_new();
    if (ctx->cctx == NULL) {
        OPENSSL_free(ctx);
        return NULL;
    }
    ctx->actx = EVP_CIPHER_CTX_new();
    if (ctx->actx == NULL) {
        EVP_CIPHER_CTX_free(ctx->cctx);
        OPENSSL_free(ctx);
        return NULL;
    }
    ctx->nlast_block = -1;
    ctx->num = 0;
    ctx->section_size = 4096; /* recommended value for Kuznyechik */
    return ctx;
}

static void CMAC_ACPKM_CTX_cleanup(CMAC_ACPKM_CTX *ctx)
{
    EVP_CIPHER_CTX_cleanup(ctx->cctx);
    EVP_CIPHER_CTX_cleanup(ctx->actx);
    OPENSSL_cleanse(ctx->tbl, EVP_MAX_BLOCK_LENGTH);
    OPENSSL_cleanse(ctx->km, ACPKM_T_MAX);
    OPENSSL_cleanse(ctx->last_block, EVP_MAX_BLOCK_LENGTH);
    ctx->nlast_block = -1;
}

static void CMAC_ACPKM_CTX_free(CMAC_ACPKM_CTX *ctx)
{
    if (!ctx)
        return;
    CMAC_ACPKM_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx->cctx);
    EVP_CIPHER_CTX_free(ctx->actx);
    OPENSSL_free(ctx);
}

static int CMAC_ACPKM_CTX_copy(CMAC_ACPKM_CTX *out, const CMAC_ACPKM_CTX *in)
{
    int bl;
    if (in->nlast_block == -1)
        return 0;
    if (!EVP_CIPHER_CTX_copy(out->cctx, in->cctx))
        return 0;
    if (!EVP_CIPHER_CTX_copy(out->actx, in->actx))
        return 0;
    bl = EVP_CIPHER_CTX_block_size(in->cctx);
    memcpy(out->km, in->km, ACPKM_T_MAX);
    memcpy(out->tbl, in->tbl, bl);
    memcpy(out->last_block, in->last_block, bl);
    out->nlast_block = in->nlast_block;
    out->section_size = in->section_size;
    out->num = in->num;
    return 1;
}

static int CMAC_ACPKM_Init(CMAC_ACPKM_CTX *ctx, const void *key, size_t keylen,
                           const EVP_CIPHER *cipher, ENGINE *impl)
{
    /* All zeros means restart */
    if (!key && !cipher && !impl && keylen == 0) {
        /* Not initialised */
        if (ctx->nlast_block == -1)
            return 0;
        if (!EVP_EncryptInit_ex(ctx->cctx, NULL, NULL, NULL, zero_iv))
            return 0;
        memset(ctx->tbl, 0, EVP_CIPHER_CTX_block_size(ctx->cctx));
        ctx->nlast_block = 0;
        /* No restart for ACPKM */
        return 1;
    }
    /* Initialise context */
    if (cipher) {
        const EVP_CIPHER *acpkm;

        if (!EVP_EncryptInit_ex(ctx->cctx, cipher, impl, NULL, NULL))
            return 0;
        if (!EVP_CIPHER_is_a(cipher, SN_grasshopper_cbc))
            return 0;
        acpkm = cipher_gost_grasshopper_ctracpkm();
        if (!EVP_EncryptInit_ex(ctx->actx, acpkm, impl, NULL, NULL))
            return 0;
    }
    /* Non-NULL key means initialisation is complete */
    if (key) {
        unsigned char acpkm_iv[EVP_MAX_BLOCK_LENGTH];
        int block_size, key_len;

        /* Initialize CTR for ACPKM-Master */
        if (!EVP_CIPHER_CTX_cipher(ctx->actx))
            return 0;
        /* block size of ACPKM cipher could be 1, but,
         * cbc cipher is same with correct block_size */
        block_size = EVP_CIPHER_CTX_block_size(ctx->cctx);
        /* Wide IV = 1^{n/2} || 0,
         * where a^r denotes the string that consists of r 'a' bits */
        memset(acpkm_iv, 0xff, block_size / 2);
        memset(acpkm_iv + block_size / 2, 0, block_size / 2);
        if (!EVP_EncryptInit_ex(ctx->actx, NULL, NULL, key, acpkm_iv))
            return 0;
        /* EVP_CIPHER key_len may be different from EVP_CIPHER_CTX key_len */
        key_len = EVP_CIPHER_key_length(EVP_CIPHER_CTX_cipher(ctx->actx));

        /* Generate first key material (K^1 || K^1_1) */
        if (!EVP_Cipher(ctx->actx, ctx->km, zero_iv, key_len + block_size))
            return 0;

        /* Initialize cbc for CMAC */
        if (!EVP_CIPHER_CTX_cipher(ctx->cctx) ||
            !EVP_CIPHER_CTX_set_key_length(ctx->cctx, key_len))
            return 0;
        /* set CBC key to K^1 */
        if (!EVP_EncryptInit_ex(ctx->cctx, NULL, NULL, ctx->km, zero_iv))
            return 0;
        ctx->nlast_block = 0;
    }
    return 1;
}

/* Encrypt zeros with master key
 * to generate T*-sized key material */
static int CMAC_ACPKM_Master(CMAC_ACPKM_CTX *ctx)
{
    return EVP_Cipher(ctx->actx, ctx->km, zero_iv,
        EVP_CIPHER_key_length(EVP_CIPHER_CTX_cipher(ctx->actx)) +
        EVP_CIPHER_CTX_block_size(ctx->cctx));
}

static int CMAC_ACPKM_Mesh(CMAC_ACPKM_CTX *ctx)
{
    if (ctx->num < ctx->section_size)
        return 1;
    ctx->num = 0;
    if (!CMAC_ACPKM_Master(ctx))
        return 0;
    /* Restart cbc with new key */
    if (!EVP_EncryptInit_ex(ctx->cctx, NULL, NULL, ctx->km,
            EVP_CIPHER_CTX_iv(ctx->cctx)))
        return 0;
    return 1;
}

static int CMAC_ACPKM_Update(CMAC_ACPKM_CTX *ctx, const void *in, size_t dlen)
{
    const unsigned char *data = in;
    size_t bl;
    if (ctx->nlast_block == -1)
        return 0;
    if (dlen == 0)
        return 1;
    bl = EVP_CIPHER_CTX_block_size(ctx->cctx);
    /* Copy into partial block if we need to */
    if (ctx->nlast_block > 0) {
        size_t nleft;
        nleft = bl - ctx->nlast_block;
        if (dlen < nleft)
            nleft = dlen;
        memcpy(ctx->last_block + ctx->nlast_block, data, nleft);
        dlen -= nleft;
        ctx->nlast_block += nleft;
        /* If no more to process return */
        if (dlen == 0)
            return 1;
        data += nleft;
        /* Else not final block so encrypt it */
        if (!CMAC_ACPKM_Mesh(ctx))
            return 0;
        if (!EVP_Cipher(ctx->cctx, ctx->tbl, ctx->last_block, bl))
            return 0;
        ctx->num += bl;
    }
    /* Encrypt all but one of the complete blocks left */
    while (dlen > bl) {
        if (!CMAC_ACPKM_Mesh(ctx))
            return 0;
        if (!EVP_Cipher(ctx->cctx, ctx->tbl, data, bl))
            return 0;
        dlen -= bl;
        data += bl;
        ctx->num += bl;
    }
    /* Copy any data left to last block buffer */
    memcpy(ctx->last_block, data, dlen);
    ctx->nlast_block = dlen;
    return 1;

}

/* Return value is propagated to EVP_DigestFinal_ex */
static int CMAC_ACPKM_Final(CMAC_ACPKM_CTX *ctx, unsigned char *out,
                            size_t *poutlen)
{
    int i, bl, lb, key_len;
    unsigned char *k1, k2[EVP_MAX_BLOCK_LENGTH];
    if (ctx->nlast_block == -1)
        return 0;
    bl = EVP_CIPHER_CTX_block_size(ctx->cctx);
    if (bl != 8 && bl != 16) {
        GOSTerr(GOST_F_OMAC_ACPKM_IMIT_FINAL, GOST_R_INVALID_MAC_PARAMS);
        return 0;
    }
    *poutlen = (size_t) bl;
    if (!out)
        return 1;
    lb = ctx->nlast_block;

    if (!CMAC_ACPKM_Mesh(ctx))
        return 0;
    key_len = EVP_CIPHER_key_length(EVP_CIPHER_CTX_cipher(ctx->actx));
    /* Keys k1 and k2 */
    k1 = ctx->km + key_len;
    make_kn(k2, ctx->km + key_len, bl);

    /* Is last block complete? */
    if (lb == bl) {
        for (i = 0; i < bl; i++)
            out[i] = ctx->last_block[i] ^ k1[i];
    } else {
        ctx->last_block[lb] = 0x80;
        if (bl - lb > 1)
            memset(ctx->last_block + lb + 1, 0, bl - lb - 1);
        for (i = 0; i < bl; i++)
            out[i] = ctx->last_block[i] ^ k2[i];
    }
    OPENSSL_cleanse(k1, bl);
    OPENSSL_cleanse(k2, bl);
    OPENSSL_cleanse(ctx->km, ACPKM_T_MAX);
    if (!EVP_Cipher(ctx->cctx, out, out, bl)) {
        OPENSSL_cleanse(out, bl);
        return 0;
    }
    return 1;
}

/*
 * End of CMAC code from crypto/cmac/cmac.c with ACPKM tweaks
 */

typedef struct omac_acpkm_ctx {
    CMAC_ACPKM_CTX *cmac_ctx;
    size_t dgst_size;
    const char *cipher_name;
    int key_set;
} OMAC_ACPKM_CTX;

#define MAX_GOST_OMAC_ACPKM_SIZE 16

static int omac_acpkm_init(EVP_MD_CTX *ctx, const char *cipher_name)
{
    OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);
    memset(c, 0, sizeof(OMAC_ACPKM_CTX));
    c->cipher_name = cipher_name;
    c->key_set = 0;

    switch (OBJ_txt2nid(cipher_name)) {
    case NID_grasshopper_cbc:
        c->dgst_size = 16;
        break;
    }

    return 1;
}

static int grasshopper_omac_acpkm_init(EVP_MD_CTX *ctx)
{
    return omac_acpkm_init(ctx, SN_grasshopper_cbc);
}

static int omac_acpkm_imit_update(EVP_MD_CTX *ctx, const void *data,
                                  size_t count)
{
    OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);
    if (!c->key_set) {
        GOSTerr(GOST_F_OMAC_ACPKM_IMIT_UPDATE, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }

    return CMAC_ACPKM_Update(c->cmac_ctx, data, count);
}

int omac_acpkm_imit_final(EVP_MD_CTX *ctx, unsigned char *md)
{
    OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);
    unsigned char mac[MAX_GOST_OMAC_ACPKM_SIZE];
    size_t mac_size = sizeof(mac);
    int ret;

    if (!c->key_set) {
        GOSTerr(GOST_F_OMAC_ACPKM_IMIT_FINAL, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }

    ret = CMAC_ACPKM_Final(c->cmac_ctx, mac, &mac_size);

    memcpy(md, mac, c->dgst_size);
    return ret;
}

static int omac_acpkm_imit_copy(EVP_MD_CTX *to, const EVP_MD_CTX *from)
{
    OMAC_ACPKM_CTX *c_to = EVP_MD_CTX_md_data(to);
    const OMAC_ACPKM_CTX *c_from = EVP_MD_CTX_md_data(from);

    if (c_from && c_to) {
        c_to->dgst_size = c_from->dgst_size;
        c_to->cipher_name = c_from->cipher_name;
        c_to->key_set = c_from->key_set;
    } else {
        return 0;
    }
    if (!c_from->cmac_ctx) {
        if (c_to->cmac_ctx) {
            CMAC_ACPKM_CTX_free(c_to->cmac_ctx);
            c_to->cmac_ctx = NULL;
        }
        return 1;
    }
    if ((c_to->cmac_ctx == c_from->cmac_ctx) || (c_to->cmac_ctx == NULL))  {
        c_to->cmac_ctx = CMAC_ACPKM_CTX_new();
    }

    return (c_to->cmac_ctx) ? CMAC_ACPKM_CTX_copy(c_to->cmac_ctx, c_from->cmac_ctx) : 0;
}

/* Clean up imit ctx */
static int omac_acpkm_imit_cleanup(EVP_MD_CTX *ctx)
{
    OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);

    if (c) {
        CMAC_ACPKM_CTX_free(c->cmac_ctx);
        memset(EVP_MD_CTX_md_data(ctx), 0, sizeof(OMAC_ACPKM_CTX));
    }
    return 1;
}

static int omac_acpkm_key(OMAC_ACPKM_CTX *c, const EVP_CIPHER *cipher,
                          const unsigned char *key, size_t key_size)
{
    int ret = 0;

    c->cmac_ctx = CMAC_ACPKM_CTX_new();
    if (c->cmac_ctx == NULL) {
        GOSTerr(GOST_F_OMAC_ACPKM_KEY, ERR_R_MALLOC_FAILURE);
        return 0;
    }

    ret = CMAC_ACPKM_Init(c->cmac_ctx, key, key_size, cipher, NULL);
    if (ret > 0) {
        c->key_set = 1;
    }
    return 1;
}

int omac_acpkm_imit_ctrl(EVP_MD_CTX *ctx, int type, int arg, void *ptr)
{
    switch (type) {
    case EVP_MD_CTRL_KEY_LEN:
        *((unsigned int *)(ptr)) = 32;
        return 1;
    case EVP_MD_CTRL_SET_KEY:
        {
            OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);
            const EVP_MD *md = EVP_MD_CTX_md(ctx);
            EVP_CIPHER *cipher = NULL;
            int ret = 0;

            if (c->cipher_name == NULL) {
                if (EVP_MD_is_a(md, SN_grasshopper_mac)
                    || EVP_MD_is_a(md, SN_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm_omac))
                    c->cipher_name = SN_grasshopper_cbc;
            }
            if ((cipher =
                 (EVP_CIPHER *)EVP_get_cipherbyname(c->cipher_name)) == NULL
                && (cipher =
                    EVP_CIPHER_fetch(NULL, c->cipher_name, NULL)) == NULL) {
                GOSTerr(GOST_F_OMAC_ACPKM_IMIT_CTRL, GOST_R_CIPHER_NOT_FOUND);
            }
            if (EVP_MD_meth_get_init(EVP_MD_CTX_md(ctx)) (ctx) <= 0) {
                GOSTerr(GOST_F_OMAC_ACPKM_IMIT_CTRL, GOST_R_MAC_KEY_NOT_SET);
                goto set_key_end;
            }
            EVP_MD_CTX_set_flags(ctx, EVP_MD_CTX_FLAG_NO_INIT);
            if (c->key_set) {
                GOSTerr(GOST_F_OMAC_ACPKM_IMIT_CTRL, GOST_R_BAD_ORDER);
                goto set_key_end;
            }
            if (arg == 0) {
                struct gost_mac_key *key = (struct gost_mac_key *)ptr;
                ret = omac_acpkm_key(c, cipher, key->key, 32);
                goto set_key_end;
            } else if (arg == 32) {
                ret = omac_acpkm_key(c, cipher, ptr, 32);
                goto set_key_end;
            }
            GOSTerr(GOST_F_OMAC_ACPKM_IMIT_CTRL, GOST_R_INVALID_MAC_KEY_SIZE);
          set_key_end:
            EVP_CIPHER_free(cipher);
            return ret;
        }
    case EVP_CTRL_KEY_MESH:
        {
            OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);
            if (!arg || (arg % EVP_MD_block_size(EVP_MD_CTX_md(ctx))))
                return -1;
            c->cmac_ctx->section_size = arg;
            if (ptr && *(int *)ptr) {
                /* Set parameter T */
                if (EVP_CIPHER_get0_provider(EVP_CIPHER_CTX_cipher(c->cmac_ctx->actx))
                    == NULL) {
                    if (!EVP_CIPHER_CTX_ctrl(c->cmac_ctx->actx, EVP_CTRL_KEY_MESH,
                                             *(int *)ptr, NULL))
                        return 0;
                } else {
                    size_t cipher_key_mesh = (size_t)*(int *)ptr;
                    OSSL_PARAM params[] = { OSSL_PARAM_END, OSSL_PARAM_END };
                    params[0] = OSSL_PARAM_construct_size_t("key-mesh",
                                                            &cipher_key_mesh);
                    if (!EVP_CIPHER_CTX_set_params(c->cmac_ctx->actx, params))
                        return 0;
                }
            }
            return 1;
        }
    case EVP_MD_CTRL_XOF_LEN:   /* Supported in OpenSSL */
        {
            OMAC_ACPKM_CTX *c = EVP_MD_CTX_md_data(ctx);
            switch (OBJ_txt2nid(c->cipher_name)) {
            case NID_grasshopper_cbc:
                if (arg < 1 || arg > 16) {
                    GOSTerr(GOST_F_OMAC_ACPKM_IMIT_CTRL, GOST_R_INVALID_MAC_SIZE);
                    return 0;
                }
                c->dgst_size = arg;
                break;
            case NID_magma_cbc:
                if (arg < 1 || arg > 8) {
                    GOSTerr(GOST_F_OMAC_ACPKM_IMIT_CTRL, GOST_R_INVALID_MAC_SIZE);
                    return 0;
                }
                c->dgst_size = arg;
                break;
            default:
                return 0;
            }
            return 1;
        }

    default:
        return 0;
    }
}

GOST_digest kuznyechik_ctracpkm_omac_digest = {
    .nid = NID_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm_omac,
    .result_size = MAX_GOST_OMAC_ACPKM_SIZE,
    .input_blocksize = GRASSHOPPER_BLOCK_SIZE,
    .app_datasize = sizeof(OMAC_ACPKM_CTX),
    .flags = EVP_MD_FLAG_XOF,
    .init = grasshopper_omac_acpkm_init,
    .update = omac_acpkm_imit_update,
    .final = omac_acpkm_imit_final,
    .copy = omac_acpkm_imit_copy,
    .cleanup = omac_acpkm_imit_cleanup,
    .ctrl = omac_acpkm_imit_ctrl,
};
