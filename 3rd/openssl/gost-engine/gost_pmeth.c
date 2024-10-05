/**********************************************************************
 *                          gost_pmeth.c                              *
 *             Copyright (c) 2005-2013 Cryptocom LTD                  *
 *         This file is distributed under the same license as OpenSSL *
 *                                                                    *
 *   Implementation of RFC 4357 (GOST R 34.10) Publick key method     *
 *       for OpenSSL                                                  *
 *          Requires OpenSSL 1.0.0+ for compilation                   *
 **********************************************************************/
#include <openssl/evp.h>
#include <openssl/objects.h>
#include <openssl/ec.h>
#include <openssl/err.h>
#include <openssl/x509v3.h>     /* For string_to_hex */
#include <openssl/opensslv.h>   /* For OPENSSL_VERSION_MAJOR */
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "gost_lcl.h"
#include "e_gost_err.h"

#define ossl3_const
#ifdef OPENSSL_VERSION_MAJOR
#undef ossl3_const
#define ossl3_const const
#endif

/* -----init, cleanup, copy - uniform for all algs  --------------*/
/* Allocates new gost_pmeth_data structure and assigns it as data */
static int pkey_gost_init(EVP_PKEY_CTX *ctx)
{
    struct gost_pmeth_data *data;
    EVP_PKEY *pkey = EVP_PKEY_CTX_get0_pkey(ctx);

    data = OPENSSL_malloc(sizeof(*data));
    if (!data)
        return 0;
    memset(data, 0, sizeof(*data));
    if (pkey && EVP_PKEY_get0(pkey)) {
        switch (EVP_PKEY_base_id(pkey)) {
        case NID_id_GostR3410_2001:
        case NID_id_GostR3410_2001DH:
        case NID_id_GostR3410_2012_256:
        case NID_id_GostR3410_2012_512:
            {
                const EC_GROUP *group =
                    EC_KEY_get0_group(EVP_PKEY_get0((EVP_PKEY *)pkey));
                if (group != NULL) {
                    data->sign_param_nid = EC_GROUP_get_curve_name(group);
                    break;
                }
                /* else */
            }
        default:
            OPENSSL_free(data);
            return 0;
        }
    }
    EVP_PKEY_CTX_set_data(ctx, data);
    return 1;
}

/* Copies contents of gost_pmeth_data structure */
static int pkey_gost_copy(EVP_PKEY_CTX *dst, ossl3_const EVP_PKEY_CTX *src)
{
    struct gost_pmeth_data *dst_data, *src_data;
    if (!pkey_gost_init(dst)) {
        return 0;
    }
    src_data = EVP_PKEY_CTX_get_data(src);
    dst_data = EVP_PKEY_CTX_get_data(dst);
    if (!src_data || !dst_data)
        return 0;

    *dst_data = *src_data;

    return 1;
}

/* Frees up gost_pmeth_data structure */
static void pkey_gost_cleanup(EVP_PKEY_CTX *ctx)
{
    struct gost_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);
    if (!data)
        return;
    OPENSSL_free(data);
}

/* --------------------- control functions  ------------------------------*/
static int pkey_gost_ctrl(EVP_PKEY_CTX *ctx, int type, int p1, void *p2)
{
    struct gost_pmeth_data *pctx =
        (struct gost_pmeth_data *)EVP_PKEY_CTX_get_data(ctx);
    if (pctx == NULL)
        return 0;

    switch (type) {
    case EVP_PKEY_CTRL_MD:
        {
            EVP_PKEY *key = EVP_PKEY_CTX_get0_pkey(ctx);
            int pkey_nid = (key == NULL) ? NID_undef : EVP_PKEY_base_id(key);

            OPENSSL_assert(p2 != NULL);

            switch (EVP_MD_type((const EVP_MD *)p2)) {
            case NID_id_GostR3411_94:
                if (pkey_nid == NID_id_GostR3410_2001
                    || pkey_nid == NID_id_GostR3410_2001DH
                    || pkey_nid == NID_id_GostR3410_94) {
                    pctx->md = (EVP_MD *)p2;
                    return 1;
                }
                break;

            case NID_id_GostR3411_2012_256:
                if (pkey_nid == NID_id_GostR3410_2012_256) {
                    pctx->md = (EVP_MD *)p2;
                    return 1;
                }
                break;

            case NID_id_GostR3411_2012_512:
                if (pkey_nid == NID_id_GostR3410_2012_512) {
                    pctx->md = (EVP_MD *)p2;
                    return 1;
                }
                break;
            }

            GOSTerr(GOST_F_PKEY_GOST_CTRL, GOST_R_INVALID_DIGEST_TYPE);
            return 0;
        }

    case EVP_PKEY_CTRL_GET_MD:
        *(const EVP_MD **)p2 = pctx->md;
        return 1;

    case EVP_PKEY_CTRL_PKCS7_ENCRYPT:
    case EVP_PKEY_CTRL_PKCS7_DECRYPT:
    case EVP_PKEY_CTRL_PKCS7_SIGN:
    case EVP_PKEY_CTRL_DIGESTINIT:
#ifndef OPENSSL_NO_CMS
    case EVP_PKEY_CTRL_CMS_ENCRYPT:
    case EVP_PKEY_CTRL_CMS_DECRYPT:
    case EVP_PKEY_CTRL_CMS_SIGN:
#endif
        return 1;

    case EVP_PKEY_CTRL_GOST_PARAMSET:
        pctx->sign_param_nid = (int)p1;
        return 1;
    case EVP_PKEY_CTRL_SET_IV:
	if (p1 > sizeof(pctx->shared_ukm) || !p2) {
	    GOSTerr(GOST_F_PKEY_GOST_CTRL, GOST_R_UKM_NOT_SET);
	    return 0;
	}
        memcpy(pctx->shared_ukm, p2, (int)p1);
        pctx->shared_ukm_size = p1;
        return 1;
    case EVP_PKEY_CTRL_SET_VKO:
	switch (p1) {
	    case 0: /* switch to KEG */
	    case NID_id_GostR3411_2012_256:
	    case NID_id_GostR3411_2012_512:
		break;
	    default:
		GOSTerr(GOST_F_PKEY_GOST_CTRL, GOST_R_INVALID_DIGEST_TYPE);
		return 0;
	}
        pctx->vko_dgst_nid = p1;
        return 1;
  case EVP_PKEY_CTRL_CIPHER:
        switch (p1) {
          case NID_magma_ctr_acpkm:
          case NID_magma_ctr_acpkm_omac:
          case NID_magma_ctr:
            pctx->cipher_nid = NID_magma_ctr;
            return 1;
          case NID_kuznyechik_ctr_acpkm:
          case NID_kuznyechik_ctr_acpkm_omac:
          case NID_kuznyechik_ctr:
            pctx->cipher_nid = NID_kuznyechik_ctr;
            return 1;
          default:
            pctx->cipher_nid = p1;
            return 1;
        }
    case EVP_PKEY_CTRL_PEER_KEY:
        if (p1 == 0 || p1 == 1) /* call from EVP_PKEY_derive_set_peer */
            return 1;
        if (p1 == 2)            /* TLS: peer key used? */
            return pctx->peer_key_used;
        if (p1 == 3)            /* TLS: peer key used! */
            return (pctx->peer_key_used = 1);
        break;
    }

    GOSTerr(GOST_F_PKEY_GOST_CTRL, GOST_R_CTRL_CALL_FAILED);
    return -2;
}

static int pkey_gost_ec_ctrl_str_common(EVP_PKEY_CTX *ctx,
                                     const char *type, const char *value)
{
  if (0 == strcmp(type, ukm_ctrl_string)) {
    unsigned char ukm_buf[32], *tmp = NULL;
    long len = 0;
    tmp = OPENSSL_hexstr2buf(value, &len);
    if (tmp == NULL)
      return 0;

    if (len > 32) {
      OPENSSL_free(tmp);
      GOSTerr(GOST_F_PKEY_GOST_EC_CTRL_STR_COMMON, GOST_R_CTRL_CALL_FAILED);
      return 0;
    }
    memcpy(ukm_buf, tmp, len);
    OPENSSL_free(tmp);

    return pkey_gost_ctrl(ctx, EVP_PKEY_CTRL_SET_IV, len, ukm_buf);
  } else if (strcmp(type, vko_ctrl_string) == 0) {
      int bits = atoi(value);
      int vko_dgst_nid = 0;

      if (bits == 256)
	  vko_dgst_nid = NID_id_GostR3411_2012_256;
      else if (bits == 512)
	  vko_dgst_nid = NID_id_GostR3411_2012_512;
      else if (bits != 0) {
	  GOSTerr(GOST_F_PKEY_GOST_EC_CTRL_STR_COMMON, GOST_R_INVALID_DIGEST_TYPE);
	  return 0;
      }
      return pkey_gost_ctrl(ctx, EVP_PKEY_CTRL_SET_VKO, vko_dgst_nid, NULL);
  }
  return -2;
}

static int pkey_gost_ec_ctrl_str_256(EVP_PKEY_CTX *ctx,
                                     const char *type, const char *value)
{
    if (strcmp(type, param_ctrl_string) == 0) {
        int param_nid = 0;

        if (!value) {
            return 0;
        }
        if (strlen(value) == 1) {
            switch (toupper((unsigned char)value[0])) {
            case 'A':
                param_nid = NID_id_GostR3410_2001_CryptoPro_A_ParamSet;
                break;
            case 'B':
                param_nid = NID_id_GostR3410_2001_CryptoPro_B_ParamSet;
                break;
            case 'C':
                param_nid = NID_id_GostR3410_2001_CryptoPro_C_ParamSet;
                break;
            case '0':
                param_nid = NID_id_GostR3410_2001_TestParamSet;
                break;
            default:
                return 0;
            }
        } else if ((strlen(value) == 2)
                   && (toupper((unsigned char)value[0]) == 'X')) {
            switch (toupper((unsigned char)value[1])) {
            case 'A':
                param_nid = NID_id_GostR3410_2001_CryptoPro_XchA_ParamSet;
                break;
            case 'B':
                param_nid = NID_id_GostR3410_2001_CryptoPro_XchB_ParamSet;
                break;
            default:
                return 0;
            }
    } else if ((strlen(value) == 3)
        && (toupper((unsigned char)value[0]) == 'T')
        && (toupper((unsigned char)value[1]) == 'C')) {
            switch (toupper((unsigned char)value[2])) {
            case 'A':
                param_nid = NID_id_tc26_gost_3410_2012_256_paramSetA;
                break;
            case 'B':
                param_nid = NID_id_tc26_gost_3410_2012_256_paramSetB;
                break;
            case 'C':
                param_nid = NID_id_tc26_gost_3410_2012_256_paramSetC;
                break;
            case 'D':
                param_nid = NID_id_tc26_gost_3410_2012_256_paramSetD;
                break;
            default:
                return 0;
            }
        } else {
            R3410_ec_params *p = R3410_2001_paramset;
            param_nid = OBJ_txt2nid(value);
            if (param_nid == NID_undef) {
                return 0;
            }
            for (; p->nid != NID_undef; p++) {
                if (p->nid == param_nid)
                    break;
            }
            if (p->nid == NID_undef) {
                GOSTerr(GOST_F_PKEY_GOST_EC_CTRL_STR_256,
                        GOST_R_INVALID_PARAMSET);
                return 0;
            }
        }

        return pkey_gost_ctrl(ctx, EVP_PKEY_CTRL_GOST_PARAMSET,
                              param_nid, NULL);
    }

    return pkey_gost_ec_ctrl_str_common(ctx, type, value);
}

static int pkey_gost_ec_ctrl_str_512(EVP_PKEY_CTX *ctx,
                                     const char *type, const char *value)
{
    int param_nid = NID_undef;

    if (strcmp(type, param_ctrl_string))
      return pkey_gost_ec_ctrl_str_common(ctx, type, value);

    if (!value)
        return 0;

    if (strlen(value) == 1) {
        switch (toupper((unsigned char)value[0])) {
        case 'A':
            param_nid = NID_id_tc26_gost_3410_2012_512_paramSetA;
            break;

        case 'B':
            param_nid = NID_id_tc26_gost_3410_2012_512_paramSetB;
            break;

        case 'C':
            param_nid = NID_id_tc26_gost_3410_2012_512_paramSetC;
            break;

        default:
            return 0;
        }
    } else {
        R3410_ec_params *p = R3410_2012_512_paramset;
        param_nid = OBJ_txt2nid(value);
        if (param_nid == NID_undef)
            return 0;

        while (p->nid != NID_undef && p->nid != param_nid)
            p++;

        if (p->nid == NID_undef) {
            GOSTerr(GOST_F_PKEY_GOST_EC_CTRL_STR_512,
                    GOST_R_INVALID_PARAMSET);
            return 0;
        }
    }

    return pkey_gost_ctrl(ctx, EVP_PKEY_CTRL_GOST_PARAMSET, param_nid, NULL);
}

/* --------------------- key generation  --------------------------------*/

static int pkey_gost_paramgen_init(EVP_PKEY_CTX *ctx)
{
    return 1;
}

static int pkey_gost2001_paramgen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    struct gost_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);
    EC_KEY *ec = NULL;

    if (!data || data->sign_param_nid == NID_undef) {
        GOSTerr(GOST_F_PKEY_GOST2001_PARAMGEN, GOST_R_NO_PARAMETERS_SET);
        return 0;
    }

    ec = EC_KEY_new();
    if (!fill_GOST_EC_params(ec, data->sign_param_nid)
        || !EVP_PKEY_assign(pkey, NID_id_GostR3410_2001, ec)) {
        EC_KEY_free(ec);
        return 0;
    }
    return 1;
}

static int pkey_gost2012_paramgen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    struct gost_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);
    EC_KEY *ec;
    int result = 0;

    if (!data || data->sign_param_nid == NID_undef) {
        GOSTerr(GOST_F_PKEY_GOST2012_PARAMGEN, GOST_R_NO_PARAMETERS_SET);
        return 0;
    }

    ec = EC_KEY_new();
    if (!fill_GOST_EC_params(ec, data->sign_param_nid)) {
        EC_KEY_free(ec);
        return 0;
    }

    switch (data->sign_param_nid) {
    case NID_id_tc26_gost_3410_2012_512_paramSetA:
    case NID_id_tc26_gost_3410_2012_512_paramSetB:
    case NID_id_tc26_gost_3410_2012_512_paramSetC:
    case NID_id_tc26_gost_3410_2012_512_paramSetTest:
        result =
            (EVP_PKEY_assign(pkey, NID_id_GostR3410_2012_512, ec)) ? 1 : 0;
        break;

    case NID_id_GostR3410_2001_CryptoPro_A_ParamSet:
    case NID_id_GostR3410_2001_CryptoPro_B_ParamSet:
    case NID_id_GostR3410_2001_CryptoPro_C_ParamSet:
    case NID_id_GostR3410_2001_CryptoPro_XchA_ParamSet:
    case NID_id_GostR3410_2001_CryptoPro_XchB_ParamSet:
    case NID_id_GostR3410_2001_TestParamSet:
    case NID_id_tc26_gost_3410_2012_256_paramSetA:
    case NID_id_tc26_gost_3410_2012_256_paramSetB:
    case NID_id_tc26_gost_3410_2012_256_paramSetC:
    case NID_id_tc26_gost_3410_2012_256_paramSetD:
        result =
            (EVP_PKEY_assign(pkey, NID_id_GostR3410_2012_256, ec)) ? 1 : 0;
        break;
    default:
        result = 0;
        break;
    }

    if (result == 0)
        EC_KEY_free(ec);

    return result;
}

/* ----------- keygen callbacks --------------------------------------*/
/* Generates GOST_R3410 2001 key and assigns it using specified type */
static int pkey_gost2001cp_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    EC_KEY *ec;
    if (!pkey_gost2001_paramgen(ctx, pkey))
        return 0;
    ec = EVP_PKEY_get0(pkey);
    gost_ec_keygen(ec);
    return 1;
}

/* Generates GOST_R3410 2012 key and assigns it using specified type */
static int pkey_gost2012cp_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    if (!pkey_gost2012_paramgen(ctx, pkey))
        return 0;

    gost_ec_keygen(EVP_PKEY_get0(pkey));
    return 1;
}

/* ----------- sign callbacks --------------------------------------*/
/*
 * Packs signature according to Cryptopro rules
 * and frees up ECDSA_SIG structure
 */
int pack_sign_cp(ECDSA_SIG *s, int order, unsigned char *sig, size_t *siglen)
{
    const BIGNUM *sig_r = NULL, *sig_s = NULL;
    ECDSA_SIG_get0(s, &sig_r, &sig_s);
    *siglen = 2 * order;
    memset(sig, 0, *siglen);
    store_bignum(sig_s, sig, order);
    store_bignum(sig_r, sig + order, order);
    ECDSA_SIG_free(s);
    return 1;
}

static int pkey_gost_ec_cp_sign(EVP_PKEY_CTX *ctx, unsigned char *sig,
                                size_t *siglen, const unsigned char *tbs,
                                size_t tbs_len)
{
    ECDSA_SIG *unpacked_sig = NULL;
    EVP_PKEY *pkey = EVP_PKEY_CTX_get0_pkey(ctx);
    int order = 0;

    if (!siglen)
        return 0;
    if (!pkey)
        return 0;

    switch (EVP_PKEY_base_id(pkey)) {
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
    case NID_id_GostR3410_2012_256:
        order = 64;
        break;
    case NID_id_GostR3410_2012_512:
        order = 128;
        break;
    default:
        return 0;
    }

    if (!sig) {
        *siglen = order;
        return 1;
    }
    unpacked_sig = gost_ec_sign(tbs, tbs_len, EVP_PKEY_get0(pkey));
    if (!unpacked_sig) {
        return 0;
    }
    return pack_sign_cp(unpacked_sig, order / 2, sig, siglen);
}

/* ------------------- verify callbacks ---------------------------*/
/* Unpack signature according to cryptopro rules  */
ECDSA_SIG *unpack_cp_signature(const unsigned char *sigbuf, size_t siglen)
{
    ECDSA_SIG *sig;
    BIGNUM *r = NULL, *s = NULL;

    sig = ECDSA_SIG_new();
    if (sig == NULL) {
        GOSTerr(GOST_F_UNPACK_CP_SIGNATURE, ERR_R_MALLOC_FAILURE);
        return NULL;
    }
    s = BN_bin2bn(sigbuf, siglen / 2, NULL);
    r = BN_bin2bn(sigbuf + siglen / 2, siglen / 2, NULL);
    ECDSA_SIG_set0(sig, r, s);
    return sig;
}

static int pkey_gost_ec_cp_verify(EVP_PKEY_CTX *ctx, const unsigned char *sig,
                                  size_t siglen, const unsigned char *tbs,
                                  size_t tbs_len)
{
    int ok = 0;
    EVP_PKEY *pub_key = EVP_PKEY_CTX_get0_pkey(ctx);
    ECDSA_SIG *s = (sig) ? unpack_cp_signature(sig, siglen) : NULL;
    if (!s)
        return 0;
#ifdef DEBUG_SIGN
    fprintf(stderr, "R=");
    BN_print_fp(stderr, ECDSA_SIG_get0_r(s));
    fprintf(stderr, "\nS=");
    BN_print_fp(stderr, ECDSA_SIG_get0_s(s));
    fprintf(stderr, "\n");
#endif
    if (pub_key)
        ok = gost_ec_verify(tbs, tbs_len, s, EVP_PKEY_get0(pub_key));
    ECDSA_SIG_free(s);
    return ok;
}

/* ------------- encrypt init -------------------------------------*/
/* Generates ephermeral key */
static int pkey_gost_encrypt_init(EVP_PKEY_CTX *ctx)
{
    return 1;
}

/* --------------- Derive init ------------------------------------*/
static int pkey_gost_derive_init(EVP_PKEY_CTX *ctx)
{
    return 1;
}

/* -------- PKEY_METHOD for GOST MAC algorithm --------------------*/
static int pkey_gost_mac_init(EVP_PKEY_CTX *ctx)
{
    struct gost_mac_pmeth_data *data = OPENSSL_malloc(sizeof(*data));
    EVP_PKEY *pkey = EVP_PKEY_CTX_get0_pkey(ctx);

    if (!data)
        return 0;
    memset(data, 0, sizeof(*data));
    data->mac_size = 4;
    data->mac_param_nid = NID_undef;

    if (pkey) {
        struct gost_mac_key *key = EVP_PKEY_get0(pkey);
        if (key) {
            data->mac_param_nid = key->mac_param_nid;
            data->mac_size = key->mac_size;
        }
    }

    EVP_PKEY_CTX_set_data(ctx, data);
    return 1;
}

static int pkey_gost_omac_init(EVP_PKEY_CTX *ctx, size_t mac_size)
{
    struct gost_mac_pmeth_data *data = OPENSSL_malloc(sizeof(*data));
    EVP_PKEY *pkey = EVP_PKEY_CTX_get0_pkey(ctx);

    if (!data)
        return 0;
    memset(data, 0, sizeof(*data));
    data->mac_size = mac_size;
    data->mac_param_nid = NID_undef;

    if (pkey) {
        struct gost_mac_key *key = EVP_PKEY_get0(pkey);
        if (key) {
            data->mac_param_nid = key->mac_param_nid;
            data->mac_size = key->mac_size;
        }
    }

    EVP_PKEY_CTX_set_data(ctx, data);
    return 1;
}

static int pkey_gost_magma_mac_init(EVP_PKEY_CTX *ctx)
{
    return pkey_gost_omac_init(ctx, 8);
}

static int pkey_gost_grasshopper_mac_init(EVP_PKEY_CTX *ctx)
{
    return pkey_gost_omac_init(ctx, 16);
}

static void pkey_gost_mac_cleanup(EVP_PKEY_CTX *ctx)
{
    struct gost_mac_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);
    if (data)
        OPENSSL_free(data);
}

static int pkey_gost_mac_copy(EVP_PKEY_CTX *dst, ossl3_const EVP_PKEY_CTX *src)
{
    struct gost_mac_pmeth_data *dst_data, *src_data;
    if (!pkey_gost_mac_init(dst)) {
        return 0;
    }
    src_data = EVP_PKEY_CTX_get_data(src);
    dst_data = EVP_PKEY_CTX_get_data(dst);
    if (!src_data || !dst_data)
        return 0;

    *dst_data = *src_data;
    return 1;
}

static int pkey_gost_mac_ctrl(EVP_PKEY_CTX *ctx, int type, int p1, void *p2)
{
    struct gost_mac_pmeth_data *data =
        (struct gost_mac_pmeth_data *)EVP_PKEY_CTX_get_data(ctx);

    switch (type) {
    case EVP_PKEY_CTRL_MD:
        {
            int nid = EVP_MD_type((const EVP_MD *)p2);
            if (nid != NID_id_Gost28147_89_MAC && nid != NID_gost_mac_12) {
                GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL,
                        GOST_R_INVALID_DIGEST_TYPE);
                return 0;
            }
            data->md = (EVP_MD *)p2;
            return 1;
        }

    case EVP_PKEY_CTRL_GET_MD:
        *(const EVP_MD **)p2 = data->md;
        return 1;

    case EVP_PKEY_CTRL_PKCS7_ENCRYPT:
    case EVP_PKEY_CTRL_PKCS7_DECRYPT:
    case EVP_PKEY_CTRL_PKCS7_SIGN:
        return 1;
    case EVP_PKEY_CTRL_SET_MAC_KEY:
        if (p1 != 32) {
            GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL, GOST_R_INVALID_MAC_KEY_LENGTH);
            return 0;
        }

        memcpy(data->key, p2, 32);
        data->key_set = 1;
        return 1;
    case EVP_PKEY_CTRL_GOST_PARAMSET:
        {
            struct gost_cipher_info *param = p2;
            data->mac_param_nid = param->nid;
            return 1;
        }
    case EVP_PKEY_CTRL_DIGESTINIT:
        {
            EVP_MD_CTX *mctx = p2;
            if (!data->key_set) {
                struct gost_mac_key *key;
                EVP_PKEY *pkey = EVP_PKEY_CTX_get0_pkey(ctx);
                if (!pkey) {
                    GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL,
                            GOST_R_MAC_KEY_NOT_SET);
                    return 0;
                }
                key = EVP_PKEY_get0(pkey);
                if (!key) {
                    GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL,
                            GOST_R_MAC_KEY_NOT_SET);
                    return 0;
                }
                return EVP_MD_meth_get_ctrl(EVP_MD_CTX_md(mctx))
                    (mctx, EVP_MD_CTRL_SET_KEY, 0, key);
            } else {
                return EVP_MD_meth_get_ctrl(EVP_MD_CTX_md(mctx))
                    (mctx, EVP_MD_CTRL_SET_KEY, 32, &(data->key));
            }
        }
    case EVP_PKEY_CTRL_MAC_LEN:
        {
            if (p1 < 1 || p1 > 8) {

                GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL, GOST_R_INVALID_MAC_SIZE);
                return 0;
            }
            data->mac_size = p1;
            return 1;
        }
    }
    return -2;
}

static int pkey_gost_mac_ctrl_str(EVP_PKEY_CTX *ctx,
                                  const char *type, const char *value)
{
    if (strcmp(type, key_ctrl_string) == 0) {
        if (strlen(value) != 32) {
            GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL_STR,
                    GOST_R_INVALID_MAC_KEY_LENGTH);
            return 0;
        }
        return pkey_gost_mac_ctrl(ctx, EVP_PKEY_CTRL_SET_MAC_KEY,
                                  32, (char *)value);
    }
    if (strcmp(type, hexkey_ctrl_string) == 0) {
        long keylen;
        int ret;
        unsigned char *keybuf = string_to_hex(value, &keylen);
        if (!keybuf || keylen != 32) {
            GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL_STR,
                    GOST_R_INVALID_MAC_KEY_LENGTH);
            OPENSSL_free(keybuf);
            return 0;
        }
        ret = pkey_gost_mac_ctrl(ctx, EVP_PKEY_CTRL_SET_MAC_KEY, 32, keybuf);
        OPENSSL_free(keybuf);
        return ret;

    }
    if (!strcmp(type, maclen_ctrl_string)) {
        char *endptr;
        long size = strtol(value, &endptr, 10);
        if (*endptr != '\0') {
            GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL_STR, GOST_R_INVALID_MAC_SIZE);
            return 0;
        }
        return pkey_gost_mac_ctrl(ctx, EVP_PKEY_CTRL_MAC_LEN, size, NULL);
    }
    if (strcmp(type, param_ctrl_string) == 0) {
        ASN1_OBJECT *obj = OBJ_txt2obj(value, 0);
        const struct gost_cipher_info *param = NULL;
        if (obj == NULL) {
            GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL_STR, GOST_R_INVALID_MAC_PARAMS);
            return 0;
        }

        param = get_encryption_params(obj);
        ASN1_OBJECT_free(obj);
        if (param == NULL) {
            GOSTerr(GOST_F_PKEY_GOST_MAC_CTRL_STR, GOST_R_INVALID_MAC_PARAMS);
            return 0;
        }


        return pkey_gost_mac_ctrl(ctx, EVP_PKEY_CTRL_GOST_PARAMSET, 0,
                                  (void *)param);
    }
    return -2;
}

static int pkey_gost_omac_ctrl(EVP_PKEY_CTX *ctx, int type, int p1, void *p2, size_t max_size)
{
    struct gost_mac_pmeth_data *data =
        (struct gost_mac_pmeth_data *)EVP_PKEY_CTX_get_data(ctx);

    switch (type) {
    case EVP_PKEY_CTRL_MD:
        {
            int nid = EVP_MD_type((const EVP_MD *)p2);
            if (nid != NID_magma_mac && nid != NID_grasshopper_mac
                && nid != NID_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm_omac /* FIXME beldmit */
                && nid != NID_id_tc26_cipher_gostr3412_2015_magma_ctracpkm_omac) {
                GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL,
                        GOST_R_INVALID_DIGEST_TYPE);
                return 0;
            }
            data->md = (EVP_MD *)p2;
            return 1;
        }

    case EVP_PKEY_CTRL_GET_MD:
        *(const EVP_MD **)p2 = data->md;
        return 1;

    case EVP_PKEY_CTRL_PKCS7_ENCRYPT:
    case EVP_PKEY_CTRL_PKCS7_DECRYPT:
    case EVP_PKEY_CTRL_PKCS7_SIGN:
        return 1;
    case EVP_PKEY_CTRL_SET_MAC_KEY:
        if (p1 != 32) {
            GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL, GOST_R_INVALID_MAC_KEY_LENGTH);
            return 0;
        }

        memcpy(data->key, p2, 32);
        data->key_set = 1;
        return 1;
    case EVP_PKEY_CTRL_DIGESTINIT:
        {
            EVP_MD_CTX *mctx = p2;
            if (!data->key_set) {
                struct gost_mac_key *key;
                EVP_PKEY *pkey = EVP_PKEY_CTX_get0_pkey(ctx);
                if (!pkey) {
                    GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL,
                            GOST_R_MAC_KEY_NOT_SET);
                    return 0;
                }
                key = EVP_PKEY_get0(pkey);
                if (!key) {
                    GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL,
                            GOST_R_MAC_KEY_NOT_SET);
                    return 0;
                }
                return EVP_MD_meth_get_ctrl(EVP_MD_CTX_md(mctx))
                    (mctx, EVP_MD_CTRL_SET_KEY, 0, key);
            } else {
                return EVP_MD_meth_get_ctrl(EVP_MD_CTX_md(mctx))
                    (mctx, EVP_MD_CTRL_SET_KEY, 32, &(data->key));
            }
        }
    case EVP_PKEY_CTRL_MAC_LEN:
        {
            if (p1 < 1 || p1 > max_size) {

                GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL, GOST_R_INVALID_MAC_SIZE);
                return 0;
            }
            data->mac_size = p1;
            return 1;
        }
    }
    return -2;
}

static int pkey_gost_magma_mac_ctrl(EVP_PKEY_CTX *ctx, int type, int p1, void *p2)
{
    return pkey_gost_omac_ctrl(ctx, type, p1, p2, 8);
}

static int pkey_gost_grasshopper_mac_ctrl(EVP_PKEY_CTX *ctx, int type, int p1, void *p2)
{
    return pkey_gost_omac_ctrl(ctx, type, p1, p2, 16);
}

static int pkey_gost_omac_ctrl_str(EVP_PKEY_CTX *ctx,
                                  const char *type, const char *value, size_t max_size)
{
    if (strcmp(type, key_ctrl_string) == 0) {
        if (strlen(value) != 32) {
            GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL_STR,
                    GOST_R_INVALID_MAC_KEY_LENGTH);
            return 0;
        }
        return pkey_gost_mac_ctrl(ctx, EVP_PKEY_CTRL_SET_MAC_KEY,
                                  32, (char *)value);
    }
    if (strcmp(type, hexkey_ctrl_string) == 0) {
        long keylen;
        int ret;
        unsigned char *keybuf = string_to_hex(value, &keylen);
        if (!keybuf || keylen != 32) {
            GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL_STR,
                    GOST_R_INVALID_MAC_KEY_LENGTH);
            OPENSSL_free(keybuf);
            return 0;
        }
        ret = pkey_gost_mac_ctrl(ctx, EVP_PKEY_CTRL_SET_MAC_KEY, 32, keybuf);
        OPENSSL_free(keybuf);
        return ret;

    }
    if (!strcmp(type, maclen_ctrl_string)) {
        char *endptr;
        long size = strtol(value, &endptr, 10);
        if (*endptr != '\0') {
            GOSTerr(GOST_F_PKEY_GOST_OMAC_CTRL_STR, GOST_R_INVALID_MAC_SIZE);
            return 0;
        }
        return pkey_gost_omac_ctrl(ctx, EVP_PKEY_CTRL_MAC_LEN, size, NULL, max_size);
    }
    return -2;
}

static int pkey_gost_magma_mac_ctrl_str(EVP_PKEY_CTX *ctx,
                                  const char *type, const char *value)
{
    return pkey_gost_omac_ctrl_str(ctx, type, value, 8);
}

static int pkey_gost_grasshopper_mac_ctrl_str(EVP_PKEY_CTX *ctx,
                                  const char *type, const char *value)
{
    return pkey_gost_omac_ctrl_str(ctx, type, value, 8);
}

static int pkey_gost_mac_keygen_base(EVP_PKEY_CTX *ctx,
                                     EVP_PKEY *pkey, int mac_nid)
{
    struct gost_mac_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);
    struct gost_mac_key *keydata;
    if (!data || !data->key_set) {
        GOSTerr(GOST_F_PKEY_GOST_MAC_KEYGEN_BASE, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }
    keydata = OPENSSL_malloc(sizeof(struct gost_mac_key));
    if (keydata == NULL)
        return 0;
    memcpy(keydata->key, data->key, 32);
    keydata->mac_param_nid = data->mac_param_nid;
    keydata->mac_size = data->mac_size;
    EVP_PKEY_assign(pkey, mac_nid, keydata);
    return 1;
}

static int pkey_gost_mac_keygen_12(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    return pkey_gost_mac_keygen_base(ctx, pkey, NID_gost_mac_12);
}

static int pkey_gost_mac_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    return pkey_gost_mac_keygen_base(ctx, pkey, NID_id_Gost28147_89_MAC);
}

static int pkey_gost_magma_mac_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    return pkey_gost_mac_keygen_base(ctx, pkey, NID_magma_mac);
}

static int pkey_gost_grasshopper_mac_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY *pkey)
{
    return pkey_gost_mac_keygen_base(ctx, pkey, NID_grasshopper_mac);
}

static int pkey_gost_mac_signctx_init(EVP_PKEY_CTX *ctx, EVP_MD_CTX *mctx)
{
    struct gost_mac_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);

    if (data == NULL) {
        pkey_gost_mac_init(ctx);
    }

    data = EVP_PKEY_CTX_get_data(ctx);
    if (!data) {
        GOSTerr(GOST_F_PKEY_GOST_MAC_SIGNCTX_INIT, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }

    return 1;
}

static int pkey_gost_magma_mac_signctx_init(EVP_PKEY_CTX *ctx, EVP_MD_CTX *mctx)
{
    struct gost_mac_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);

    if (data == NULL) {
        pkey_gost_omac_init(ctx, 4);
    }

    data = EVP_PKEY_CTX_get_data(ctx);
    if (!data) {
        GOSTerr(GOST_F_PKEY_GOST_MAGMA_MAC_SIGNCTX_INIT, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }

    return 1;
}

static int pkey_gost_grasshopper_mac_signctx_init(EVP_PKEY_CTX *ctx, EVP_MD_CTX *mctx)
{
    struct gost_mac_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);

    if (data == NULL) {
        pkey_gost_omac_init(ctx, 8);
    }

    data = EVP_PKEY_CTX_get_data(ctx);
    if (!data) {
        GOSTerr(GOST_F_PKEY_GOST_GRASSHOPPER_MAC_SIGNCTX_INIT, GOST_R_MAC_KEY_NOT_SET);
        return 0;
    }

    return 1;
}

static int pkey_gost_mac_signctx(EVP_PKEY_CTX *ctx, unsigned char *sig,
                                 size_t *siglen, EVP_MD_CTX *mctx)
{
    unsigned int tmpsiglen;
    int ret;
    struct gost_mac_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);

    if (!siglen)
        return 0;
    tmpsiglen = *siglen;        /* for platforms where sizeof(int) !=
                                 * sizeof(size_t) */

    if (!sig) {
        *siglen = data->mac_size;
        return 1;
    }

    EVP_MD_meth_get_ctrl(EVP_MD_CTX_md(mctx))
        (mctx, EVP_MD_CTRL_XOF_LEN, data->mac_size, NULL);
    ret = EVP_DigestFinal_ex(mctx, sig, &tmpsiglen);
    *siglen = data->mac_size;
    return ret;
}

/* ----------- misc callbacks -------------------------------------*/

/* Callback for both EVP_PKEY_check() and EVP_PKEY_public_check. */
static int pkey_gost_check(EVP_PKEY *pkey)
{
    return EC_KEY_check_key(EVP_PKEY_get0(pkey));
}

/* ----------------------------------------------------------------*/
int register_pmeth_gost(int id, EVP_PKEY_METHOD **pmeth, int flags)
{
    *pmeth = EVP_PKEY_meth_new(id, flags);
    if (!*pmeth)
        return 0;

    switch (id) {
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
        EVP_PKEY_meth_set_ctrl(*pmeth,
                               pkey_gost_ctrl, pkey_gost_ec_ctrl_str_256);
        EVP_PKEY_meth_set_sign(*pmeth, NULL, pkey_gost_ec_cp_sign);
        EVP_PKEY_meth_set_verify(*pmeth, NULL, pkey_gost_ec_cp_verify);

        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost2001cp_keygen);

        EVP_PKEY_meth_set_encrypt(*pmeth,
                                  pkey_gost_encrypt_init,
                                  pkey_gost_encrypt);
        EVP_PKEY_meth_set_decrypt(*pmeth, NULL, pkey_gost_decrypt);
        EVP_PKEY_meth_set_derive(*pmeth,
                                 pkey_gost_derive_init, pkey_gost_ec_derive);
        EVP_PKEY_meth_set_paramgen(*pmeth, pkey_gost_paramgen_init,
                                   pkey_gost2001_paramgen);
    EVP_PKEY_meth_set_check(*pmeth, pkey_gost_check);
    EVP_PKEY_meth_set_public_check(*pmeth, pkey_gost_check);
        break;
    case NID_id_GostR3410_2012_256:
        EVP_PKEY_meth_set_ctrl(*pmeth,
                               pkey_gost_ctrl, pkey_gost_ec_ctrl_str_256);
        EVP_PKEY_meth_set_sign(*pmeth, NULL, pkey_gost_ec_cp_sign);
        EVP_PKEY_meth_set_verify(*pmeth, NULL, pkey_gost_ec_cp_verify);

        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost2012cp_keygen);

        EVP_PKEY_meth_set_encrypt(*pmeth,
                                  pkey_gost_encrypt_init,
                                  pkey_gost_encrypt);
        EVP_PKEY_meth_set_decrypt(*pmeth, NULL, pkey_gost_decrypt);
        EVP_PKEY_meth_set_derive(*pmeth,
                                 pkey_gost_derive_init, pkey_gost_ec_derive);
        EVP_PKEY_meth_set_paramgen(*pmeth,
                                   pkey_gost_paramgen_init,
                                   pkey_gost2012_paramgen);
    EVP_PKEY_meth_set_check(*pmeth, pkey_gost_check);
    EVP_PKEY_meth_set_public_check(*pmeth, pkey_gost_check);
        break;
    case NID_id_GostR3410_2012_512:
        EVP_PKEY_meth_set_ctrl(*pmeth,
                               pkey_gost_ctrl, pkey_gost_ec_ctrl_str_512);
        EVP_PKEY_meth_set_sign(*pmeth, NULL, pkey_gost_ec_cp_sign);
        EVP_PKEY_meth_set_verify(*pmeth, NULL, pkey_gost_ec_cp_verify);

        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost2012cp_keygen);

        EVP_PKEY_meth_set_encrypt(*pmeth,
                                  pkey_gost_encrypt_init,
                                  pkey_gost_encrypt);
        EVP_PKEY_meth_set_decrypt(*pmeth, NULL, pkey_gost_decrypt);
        EVP_PKEY_meth_set_derive(*pmeth,
                                 pkey_gost_derive_init, pkey_gost_ec_derive);
        EVP_PKEY_meth_set_paramgen(*pmeth,
                                   pkey_gost_paramgen_init,
                                   pkey_gost2012_paramgen);
    EVP_PKEY_meth_set_check(*pmeth, pkey_gost_check);
    EVP_PKEY_meth_set_public_check(*pmeth, pkey_gost_check);
        break;
    case NID_id_Gost28147_89_MAC:
        EVP_PKEY_meth_set_ctrl(*pmeth, pkey_gost_mac_ctrl,
                               pkey_gost_mac_ctrl_str);
        EVP_PKEY_meth_set_signctx(*pmeth, pkey_gost_mac_signctx_init,
                                  pkey_gost_mac_signctx);
        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost_mac_keygen);
        EVP_PKEY_meth_set_init(*pmeth, pkey_gost_mac_init);
        EVP_PKEY_meth_set_cleanup(*pmeth, pkey_gost_mac_cleanup);
        EVP_PKEY_meth_set_copy(*pmeth, pkey_gost_mac_copy);
        return 1;
    case NID_gost_mac_12:
        EVP_PKEY_meth_set_ctrl(*pmeth, pkey_gost_mac_ctrl,
                               pkey_gost_mac_ctrl_str);
        EVP_PKEY_meth_set_signctx(*pmeth, pkey_gost_mac_signctx_init,
                                  pkey_gost_mac_signctx);
        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost_mac_keygen_12);
        EVP_PKEY_meth_set_init(*pmeth, pkey_gost_mac_init);
        EVP_PKEY_meth_set_cleanup(*pmeth, pkey_gost_mac_cleanup);
        EVP_PKEY_meth_set_copy(*pmeth, pkey_gost_mac_copy);
        return 1;
    case NID_magma_mac:
        EVP_PKEY_meth_set_ctrl(*pmeth, pkey_gost_magma_mac_ctrl,
                               pkey_gost_magma_mac_ctrl_str);
        EVP_PKEY_meth_set_signctx(*pmeth, pkey_gost_magma_mac_signctx_init,
                                  pkey_gost_mac_signctx);
        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost_magma_mac_keygen);
        EVP_PKEY_meth_set_init(*pmeth, pkey_gost_magma_mac_init);
        EVP_PKEY_meth_set_cleanup(*pmeth, pkey_gost_mac_cleanup);
        EVP_PKEY_meth_set_copy(*pmeth, pkey_gost_mac_copy);
        return 1;
    case NID_grasshopper_mac:
    case NID_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm_omac: /* FIXME beldmit */
        EVP_PKEY_meth_set_ctrl(*pmeth, pkey_gost_grasshopper_mac_ctrl,
                               pkey_gost_grasshopper_mac_ctrl_str);
        EVP_PKEY_meth_set_signctx(*pmeth, pkey_gost_grasshopper_mac_signctx_init,
                                  pkey_gost_mac_signctx);
        EVP_PKEY_meth_set_keygen(*pmeth, NULL, pkey_gost_grasshopper_mac_keygen);
        EVP_PKEY_meth_set_init(*pmeth, pkey_gost_grasshopper_mac_init);
        EVP_PKEY_meth_set_cleanup(*pmeth, pkey_gost_mac_cleanup);
        EVP_PKEY_meth_set_copy(*pmeth, pkey_gost_mac_copy);
        return 1;
    default:                   /* Unsupported method */
        return 0;
    }
    EVP_PKEY_meth_set_init(*pmeth, pkey_gost_init);
    EVP_PKEY_meth_set_cleanup(*pmeth, pkey_gost_cleanup);

    EVP_PKEY_meth_set_copy(*pmeth, pkey_gost_copy);
    /*
     * FIXME derive etc...
     */

    return 1;
}
