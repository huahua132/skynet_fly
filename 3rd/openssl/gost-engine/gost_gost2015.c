/*
 * Copyright (c) 2020 Dmitry Belyavskiy <beldmit@gmail.com>
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */
#include "gost_lcl.h"
#include "gost_gost2015.h"
#include "gost_grasshopper_defines.h"
#include "gost_grasshopper_math.h"
#include "e_gost_err.h"
#include <string.h>
#include <openssl/rand.h>

int gost2015_final_call(EVP_CIPHER_CTX *ctx, EVP_MD_CTX *omac_ctx, size_t mac_size,
    unsigned char *encrypted_mac,
    int (*do_cipher) (EVP_CIPHER_CTX *ctx,
    unsigned char *out,
    const unsigned char *in,
    size_t inl))
{
    unsigned char calculated_mac[KUZNYECHIK_MAC_MAX_SIZE];
    memset(calculated_mac, 0, KUZNYECHIK_MAC_MAX_SIZE);

    if (EVP_CIPHER_CTX_encrypting(ctx)) {
        EVP_DigestSignFinal(omac_ctx, calculated_mac, &mac_size);

        if (do_cipher(ctx, encrypted_mac, calculated_mac, mac_size) <= 0) {
            return -1;
        }
    } else {
        unsigned char expected_mac[KUZNYECHIK_MAC_MAX_SIZE];

        memset(expected_mac, 0, KUZNYECHIK_MAC_MAX_SIZE);
        EVP_DigestSignFinal(omac_ctx, calculated_mac, &mac_size);

        if (do_cipher(ctx, expected_mac, encrypted_mac, mac_size) <= 0) {
            return -1;
        }

        if (CRYPTO_memcmp(expected_mac, calculated_mac, mac_size) != 0)
            return -1;
    }
    return 0;
}

/*
 * UKM = iv|kdf_seed
 * */
#define MAX_GOST2015_UKM_SIZE 16
#define KDF_SEED_SIZE 8
int gost2015_get_asn1_params(const ASN1_TYPE *params, size_t ukm_size,
    unsigned char *iv, size_t ukm_offset, unsigned char *kdf_seed)
{
    int iv_len = 16;
    GOST2015_CIPHER_PARAMS *gcp = NULL;

    unsigned char *p = NULL;

    memset(iv, 0, iv_len);

    /* Проверяем тип params */
    if (ASN1_TYPE_get(params) != V_ASN1_SEQUENCE) {
        GOSTerr(GOST_F_GOST2015_GET_ASN1_PARAMS, GOST_R_INVALID_CIPHER_PARAMS);
        return 0;
    }

    p = params->value.sequence->data;
    /* Извлекаем структуру параметров */
    gcp = d2i_GOST2015_CIPHER_PARAMS(NULL, (const unsigned char **)&p, params->value.sequence->length);
    if (gcp == NULL) {
        GOSTerr(GOST_F_GOST2015_GET_ASN1_PARAMS, GOST_R_INVALID_CIPHER_PARAMS);
        return 0;
    }

    /* Проверяем длину синхропосылки */
    if (gcp->ukm->length != (int)ukm_size) {
        GOSTerr(GOST_F_GOST2015_GET_ASN1_PARAMS, GOST_R_INVALID_CIPHER_PARAMS);
        GOST2015_CIPHER_PARAMS_free(gcp);
        return 0;
    }

    memcpy(iv, gcp->ukm->data, ukm_offset);
    memcpy(kdf_seed, gcp->ukm->data+ukm_offset, KDF_SEED_SIZE);

    GOST2015_CIPHER_PARAMS_free(gcp);
    return 1;
}

int gost2015_set_asn1_params(ASN1_TYPE *params,
    const unsigned char *iv, size_t iv_size, const unsigned char *kdf_seed)
{
    GOST2015_CIPHER_PARAMS *gcp = GOST2015_CIPHER_PARAMS_new();
    int ret = 0, len = 0;

    ASN1_OCTET_STRING *os = NULL;
    unsigned char ukm_buf[MAX_GOST2015_UKM_SIZE];
    unsigned char *buf = NULL;

    if (gcp == NULL) {
        GOSTerr(GOST_F_GOST2015_SET_ASN1_PARAMS, ERR_R_MALLOC_FAILURE);
        return 0;
    }

    memcpy(ukm_buf, iv, iv_size);
    memcpy(ukm_buf+iv_size, kdf_seed, KDF_SEED_SIZE);

    if (ASN1_STRING_set(gcp->ukm, ukm_buf, iv_size + KDF_SEED_SIZE) == 0) {
        GOSTerr(GOST_F_GOST2015_SET_ASN1_PARAMS, ERR_R_MALLOC_FAILURE);
        goto end;
    }

    len = i2d_GOST2015_CIPHER_PARAMS(gcp, &buf);

    if (len <= 0
       || (os = ASN1_OCTET_STRING_new()) == NULL
       || ASN1_OCTET_STRING_set(os, buf, len) == 0) {
        goto end;
  }

    ASN1_TYPE_set(params, V_ASN1_SEQUENCE, os);
    ret = 1;

end:
    OPENSSL_free(buf);
    if (ret <= 0 && os)
        ASN1_OCTET_STRING_free(os);

    GOST2015_CIPHER_PARAMS_free(gcp);
    return ret;
}

int gost2015_process_unprotected_attributes(
    STACK_OF(X509_ATTRIBUTE) *attrs,
    int encryption, size_t mac_len, unsigned char *final_tag)
{
    if (encryption == 0) /*Decrypting*/ {
        ASN1_OCTET_STRING *osExpectedMac = X509at_get0_data_by_OBJ(attrs,
            OBJ_txt2obj(OID_GOST_CMS_MAC, 1), -3, V_ASN1_OCTET_STRING);

        if (!osExpectedMac || osExpectedMac->length != (int)mac_len)
            return -1;

        memcpy(final_tag, osExpectedMac->data, osExpectedMac->length);
    } else {
        if (attrs == NULL)
            return -1;
        return (X509at_add1_attr_by_OBJ(&attrs,
               OBJ_txt2obj(OID_GOST_CMS_MAC, 1),
               V_ASN1_OCTET_STRING, final_tag,
               mac_len) == NULL) ? -1 : 1;
    }
    return 1;
}

int gost2015_acpkm_omac_init(int nid, int enc, const unsigned char *inkey,
                             EVP_MD_CTX *omac_ctx,
                             unsigned char *outkey, unsigned char *kdf_seed)
{
    int ret = 0;
    unsigned char keys[64];
    const EVP_MD *md = EVP_get_digestbynid(nid);
    EVP_PKEY *mac_key;

    if (md == NULL)
        return 0;

    if (enc) {
        if (RAND_bytes(kdf_seed, 8) != 1)
            return 0;
    }

    if (gost_kdftree2012_256(keys, 64, inkey, 32,
       (const unsigned char *)"kdf tree", 8, kdf_seed, 8, 1) <= 0)
        return 0;

    mac_key = EVP_PKEY_new_mac_key(nid, NULL, keys+32, 32);

    if (mac_key == NULL)
        goto end;

    if (EVP_DigestInit_ex(omac_ctx, md, NULL) <= 0 ||
       EVP_DigestSignInit(omac_ctx, NULL, md, NULL, mac_key) <= 0)
        goto end;

    memcpy(outkey, keys, 32);

    ret = 1;
end:
    EVP_PKEY_free(mac_key);
    OPENSSL_cleanse(keys, sizeof(keys));

    return ret;
}

int init_zero_kdf_seed(unsigned char *kdf_seed)
{
    int is_zero_kdfseed = 1, i;
    for (i = 0; i < 8; i++) {
        if (kdf_seed[i] != 0)
            is_zero_kdfseed = 0;
    }

    return is_zero_kdfseed ? RAND_bytes(kdf_seed, 8) : 1;
}

void gost_mgm128_init(mgm128_context *ctx, void *key, block128_f block, mul128_f mul_gf, int blen)
{
    memset(ctx, 0, sizeof(*ctx));
    ctx->block = block;
    ctx->mul_gf = mul_gf;
    ctx->key = key;
    ctx->blocklen = blen;

    /* some precalculations place here
     *
     */
}

int gost_mgm128_setiv(mgm128_context *ctx, const unsigned char *iv,
                         size_t len)
{
    ctx->len.u[0] = 0;          /* AAD length */
    ctx->len.u[1] = 0;          /* message length */
    ctx->ares = 0;
    ctx->mres = 0;

    ctx->ACi.u[0] = 0;
    ctx->ACi.u[1] = 0;
    ctx->sum.u[0] = 0;
    ctx->sum.u[1] = 0;

    memcpy(ctx->nonce.c, iv, ctx->blocklen);
    ctx->nonce.c[0] &= 0x7f;    /* IV - random vector, but 1st bit should be 0 */
    return 1;
}

int gost_mgm128_aad(mgm128_context *ctx, const unsigned char *aad,
                      size_t len)
{
    size_t i;
    unsigned int n;
    uint64_t alen = ctx->len.u[0];
    block128_f block = ctx->block;
    mul128_f mul_gf = ctx->mul_gf;
    void *key = ctx->key;
    int bl = ctx->blocklen;

    if (ctx->len.u[1]) {
        GOSTerr(GOST_F_GOST_MGM128_AAD,
                GOST_R_BAD_ORDER);
        return -2;
    }

    if (alen == 0) {
        ctx->nonce.c[0] |= 0x80;
        (*block) (ctx->nonce.c, ctx->Zi.c, key);    // Z_1 = E_K(1 || nonce)
    }

    alen += len;
    if (alen > ((ossl_uintmax_t)(1) << (bl * 4 - 3)) ||      // < 2^(n/2)  (len stores in bytes)
        (sizeof(len) == 8 && alen < len)) {
            GOSTerr(GOST_F_GOST_MGM128_AAD,
                    GOST_R_DATA_TOO_LARGE);
            return -1;
        }
    ctx->len.u[0] = alen;

    n = ctx->ares;
    if (n) {
        /* Finalize partial_data */
        while (n && len) {
            ctx->ACi.c[n] = *(aad++);
            --len;
            n = (n + 1) % bl;
        }
        if (n == 0) {
            (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
            mul_gf(ctx->mul.u, ctx->Hi.u, ctx->ACi.u);              // H_i (x) A_i
            grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
              (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
            inc_counter(ctx->Zi.c, bl / 2);                              // Z_{i+1} = incr_l(Z_i)
        } else {
            ctx->ares = n;
            return 0;
        }
    }
    while (len >= bl) {
        (*block) (ctx->Zi.c, ctx->Hi.c, key);                       // H_i = E_K(Z_i)
        mul_gf(ctx->mul.u, ctx->Hi.u, (uint64_t *)aad);             // H_i (x) A_i
        grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,        // acc XOR
            (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
        inc_counter(ctx->Zi.c, bl / 2);                                  // Z_{i+1} = incr_l(Z_i)
        aad += bl;
        len -= bl;
    }
    if (len) {
        n = (unsigned int)len;
        for (i = 0; i < len; ++i)
            ctx->ACi.c[i] = aad[i];
    }

    ctx->ares = n;
    return 0;
}

int gost_mgm128_encrypt(mgm128_context *ctx, const unsigned char *in,
                          unsigned char *out, size_t len)
{
    size_t i;
    unsigned int n, mres;
    uint64_t alen = ctx->len.u[0];
    uint64_t mlen = ctx->len.u[1];
    block128_f block = ctx->block;
    mul128_f mul_gf = ctx->mul_gf;
    void *key = ctx->key;
    int bl = ctx->blocklen;

    if (mlen == 0) {
        if (alen == 0) {
            ctx->nonce.c[0] |= 0x80;
            (*block) (ctx->nonce.c, ctx->Zi.c, key);    // Z_1 = E_K(1 || nonce)
        }
        ctx->nonce.c[0] &= 0x7f;
        (*block) (ctx->nonce.c, ctx->Yi.c, key);    // Y_1 = E_K(0 || nonce)
    }

    mlen += len;

    if (mlen > ((ossl_uintmax_t)(1) << (bl * 4 - 3)) ||     // < 2^(n/2)  (len stores in bytes)
        (sizeof(len) == 8 && mlen < len) ||
        (mlen + alen) > ((ossl_uintmax_t)(1) << (bl * 4 - 3))) {
            GOSTerr(GOST_F_GOST_MGM128_ENCRYPT,
                    GOST_R_DATA_TOO_LARGE);
            return -1;
        }
    ctx->len.u[1] = mlen;

    mres = ctx->mres;

    if (ctx->ares) {
        /* First call to encrypt finalizes AAD */
        memset(ctx->ACi.c + ctx->ares, 0, bl - ctx->ares);
        (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
        mul_gf(ctx->mul.u, ctx->Hi.u, ctx->ACi.u);              // H_i (x) A_i
        grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
            (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
        inc_counter(ctx->Zi.c, bl / 2);                         // Z_{i+1} = incr_l(Z_i)

        ctx->ares = 0;
    }

    n = mres % bl;
    // TODO: replace with full blocks processing
    for (i = 0; i < len; ++i) {
        if (n == 0) {
            (*block) (ctx->Yi.c, ctx->EKi.c, key);          // E_K(Y_i)
            inc_counter(ctx->Yi.c + bl / 2, bl / 2);        // Y_i = incr_r(Y_{i-1})
        }
        ctx->ACi.c[n] = out[i] = in[i] ^ ctx->EKi.c[n];     // C_i = P_i (xor) E_K(Y_i)
        mres = n = (n + 1) % bl;
        if (n == 0) {
            (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
            mul_gf(ctx->mul.u, ctx->Hi.u, ctx->ACi.u);              // H_i (x) C_i
            grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
                (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
            inc_counter(ctx->Zi.c, bl / 2);                         // Z_{i+1} = incr_l(Z_i)
        }
    }

    ctx->mres = mres;
    return 0;
}

int gost_mgm128_decrypt(mgm128_context *ctx, const unsigned char *in,
                          unsigned char *out, size_t len)
{
    size_t i;
    unsigned int n, mres;
    uint64_t alen = ctx->len.u[0];
    uint64_t mlen = ctx->len.u[1];
    block128_f block = ctx->block;
    mul128_f mul_gf = ctx->mul_gf;
    void *key = ctx->key;
    int bl = ctx->blocklen;

    if (mlen == 0) {
        ctx->nonce.c[0] &= 0x7f;
        (*block) (ctx->nonce.c, ctx->Yi.c, key);  // Y_1 = E_K(0 || nonce)
    }

    mlen += len;
    if (mlen > ((ossl_uintmax_t)(1) << (bl * 4 - 3)) ||     // < 2^(n/2)  (len stores in bytes)
        (sizeof(len) == 8 && mlen < len) ||
        (mlen + alen) > ((ossl_uintmax_t)(1) << (bl * 4 - 3))) {
            GOSTerr(GOST_F_GOST_MGM128_DECRYPT,
                    GOST_R_DATA_TOO_LARGE);
            return -1;
        }
    ctx->len.u[1] = mlen;

    mres = ctx->mres;

    if (ctx->ares) {
        /* First call to encrypt finalizes AAD */
        memset(ctx->ACi.c + ctx->ares, 0, bl - ctx->ares);
        (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
        mul_gf(ctx->mul.u, ctx->Hi.u, ctx->ACi.u);              // H_i (x) A_i
        grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
            (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
        inc_counter(ctx->Zi.c, bl / 2);                         // Z_{i+1} = incr_l(Z_i)

        ctx->ares = 0;
    }

    n = mres % bl;
    // TODO: replace with full blocks processing
    for (i = 0; i < len; ++i) {
        uint8_t c;
        if (n == 0) {
            (*block) (ctx->Yi.c, ctx->EKi.c, key);      // E_K(Y_i)
            inc_counter(ctx->Yi.c + bl / 2, bl / 2);    // Y_i = incr_r(Y_{i-1})
        }
        ctx->ACi.c[n] = c = in[i];
        out[i] = c ^ ctx->EKi.c[n];             // P_i = C_i (xor) E_K(Y_i)
        mres = n = (n + 1) % bl;
        if (n == 0) {
            (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
            mul_gf(ctx->mul.u, ctx->Hi.u, ctx->ACi.u);              // H_i (x) C_i
            grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
                (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
            inc_counter(ctx->Zi.c, bl / 2);                         // Z_{i+1} = incr_l(Z_i)
        }
    }

    ctx->mres = mres;
    return 0;
}

int gost_mgm128_finish(mgm128_context *ctx, const unsigned char *tag,
                         size_t len)
{
    uint64_t alen = ctx->len.u[0] << 3;
    uint64_t clen = ctx->len.u[1] << 3;
    block128_f block = ctx->block;
    mul128_f mul_gf = ctx->mul_gf;
    void *key = ctx->key;
    int bl = ctx->blocklen;

    if (ctx->mres || ctx->ares) {
        /* First call to encrypt finalizes AAD/ENC */
        memset(ctx->ACi.c + ctx->ares + ctx->mres, 0, bl - (ctx->ares + ctx->mres));
        (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
        mul_gf(ctx->mul.u, ctx->Hi.u, ctx->ACi.u);              // H_i (x) [A_i or C_i]
        grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
            (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
        inc_counter(ctx->Zi.c, bl / 2);                         // Z_{i+1} = incr_l(Z_i)
    }

#ifdef L_ENDIAN
    alen = BSWAP64(alen);
    clen = BSWAP64(clen);
#endif
    if (bl == 16) {
        ctx->len.u[0] = alen;
        ctx->len.u[1] = clen;
    } else {
#ifdef L_ENDIAN
        ctx->len.u[0] = (alen >> 32) | clen;
#else
        ctx->len.u[0] = (alen << 32) | clen;
#endif
        ctx->len.u[1] = 0;
    }

    (*block) (ctx->Zi.c, ctx->Hi.c, key);                   // H_i = E_K(Z_i)
    mul_gf(ctx->mul.u, ctx->Hi.u, ctx->len.u);              // H_i (x) (len(A) || len(C))
    grasshopper_plus128((grasshopper_w128_t*)ctx->sum.u,    // acc XOR
            (grasshopper_w128_t*)ctx->sum.u, (grasshopper_w128_t*)ctx->mul.u);
    (*block) (ctx->sum.c, ctx->tag.c, key);                 // E_K(sum)

    if (tag && len <= sizeof(ctx->tag))
        return CRYPTO_memcmp(ctx->tag.c, tag, len);         // MSB_S(E_K(sum))
    else
        return -1;
}

void gost_mgm128_tag(mgm128_context *ctx, unsigned char *tag, size_t len)
{
    gost_mgm128_finish(ctx, NULL, 0);
    memcpy(tag, ctx->tag.c,
           len <= sizeof(ctx->tag.c) ? len : sizeof(ctx->tag.c));
}
