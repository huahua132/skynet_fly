/**********************************************************************
 *                          gost_ameth.c                              *
 *             Copyright (c) 2005-2006 Cryptocom LTD                  *
 *         This file is distributed under the same license as OpenSSL *
 *                                                                    *
 *       Implementation of RFC 4490/4491 ASN1 method                  *
 *       for OpenSSL                                                  *
 *          Requires OpenSSL 0.9.9 for compilation                    *
 **********************************************************************/
#include <string.h>
#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/engine.h>
#include <openssl/evp.h>
#include <openssl/asn1.h>
#ifndef OPENSSL_NO_CMS
# include <openssl/cms.h>
#endif
#include "gost_lcl.h"
#include "e_gost_err.h"

#define PK_WRAP_PARAM "LEGACY_PK_WRAP"

/*
 * Pack bignum into byte buffer of given size, filling all leading bytes by
 * zeros
 */
int store_bignum(const BIGNUM *bn, unsigned char *buf, int len)
{
    int bytes = BN_num_bytes(bn);

    if (bytes > len)
        return 0;
    memset(buf, 0, len);
    BN_bn2bin(bn, buf + len - bytes);
    return 1;
}

static int pkey_bits_gost(const EVP_PKEY *pk)
{
    if (!pk)
        return -1;

    switch (EVP_PKEY_base_id(pk)) {
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
    case NID_id_GostR3410_2012_256:
        return 256;
    case NID_id_GostR3410_2012_512:
        return 512;
    }

    return -1;
}

static ASN1_STRING *encode_gost_algor_params(const EVP_PKEY *key)
{
    ASN1_STRING *params = ASN1_STRING_new();
    GOST_KEY_PARAMS *gkp = GOST_KEY_PARAMS_new();
    int pkey_param_nid = NID_undef;
    void *key_ptr = EVP_PKEY_get0((EVP_PKEY *)key);
    int result = 0;

    if (!params || !gkp) {
        GOSTerr(GOST_F_ENCODE_GOST_ALGOR_PARAMS, ERR_R_MALLOC_FAILURE);
        goto err;
    }
    switch (EVP_PKEY_base_id(key)) {
    case NID_id_GostR3410_2012_256:
        pkey_param_nid = EC_GROUP_get_curve_name(EC_KEY_get0_group(key_ptr));
	switch (pkey_param_nid) {
	    case NID_id_GostR3410_2001_TestParamSet:
	    case NID_id_GostR3410_2001_CryptoPro_A_ParamSet:
	    case NID_id_GostR3410_2001_CryptoPro_B_ParamSet:
	    case NID_id_GostR3410_2001_CryptoPro_C_ParamSet:
	    case NID_id_GostR3410_2001_CryptoPro_XchA_ParamSet:
	    case NID_id_GostR3410_2001_CryptoPro_XchB_ParamSet:
		gkp->hash_params = OBJ_nid2obj(NID_id_GostR3411_2012_256);
	}
        break;
    case NID_id_GostR3410_2012_512:
        pkey_param_nid = EC_GROUP_get_curve_name(EC_KEY_get0_group(key_ptr));
	switch (pkey_param_nid) {
	    case NID_id_tc26_gost_3410_2012_512_paramSetTest:
	    case NID_id_tc26_gost_3410_2012_512_paramSetA:
	    case NID_id_tc26_gost_3410_2012_512_paramSetB:
		gkp->hash_params = OBJ_nid2obj(NID_id_GostR3411_2012_512);
	}
        break;
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
        pkey_param_nid = EC_GROUP_get_curve_name(EC_KEY_get0_group(key_ptr));
        gkp->hash_params = OBJ_nid2obj(NID_id_GostR3411_94_CryptoProParamSet);
        break;
    }

    if (pkey_param_nid == NID_undef) {
        GOSTerr(GOST_F_ENCODE_GOST_ALGOR_PARAMS, GOST_R_INVALID_PARAMSET);
        goto err;
    }

    gkp->key_params = OBJ_nid2obj(pkey_param_nid);
    /*
     * gkp->cipher_params = OBJ_nid2obj(cipher_param_nid);
     */
    params->length = i2d_GOST_KEY_PARAMS(gkp, &params->data);
    if (params->length <= 0) {
        GOSTerr(GOST_F_ENCODE_GOST_ALGOR_PARAMS, ERR_R_MALLOC_FAILURE);
        goto err;
    }
    params->type = V_ASN1_SEQUENCE;
    result = 1;
 err:
    if (gkp)
        GOST_KEY_PARAMS_free(gkp);
    if (result == 0) {          /* if error */
        if (params)
            ASN1_STRING_free(params);
        return NULL;
    }
    return params;
}

static int gost_decode_nid_params(EVP_PKEY *pkey, int pkey_nid, int param_nid)
{
    void *key_ptr = EVP_PKEY_get0(pkey);

    switch (pkey_nid) {
    case NID_id_GostR3410_2012_256:
    case NID_id_GostR3410_2012_512:
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
        if (!key_ptr) {
            key_ptr = EC_KEY_new();
            if (!EVP_PKEY_assign(pkey, pkey_nid, key_ptr)) {
                EC_KEY_free(key_ptr);
                break;
            }
        }
        return fill_GOST_EC_params(key_ptr, param_nid);
    }

    return 0;
}

/*
 * Parses GOST algorithm parameters from X509_ALGOR and modifies pkey setting
 * NID and parameters
 */
static int decode_gost_algor_params(EVP_PKEY *pkey,
                                    const X509_ALGOR *palg)
{
    const ASN1_OBJECT *palg_obj = NULL;
    int ptype = V_ASN1_UNDEF;
    int pkey_nid = NID_undef, param_nid = NID_undef;
    ASN1_STRING *pval = NULL;
    const unsigned char *p;
    GOST_KEY_PARAMS *gkp = NULL;

    if (!pkey || !palg)
        return 0;
    X509_ALGOR_get0(&palg_obj, &ptype, (const void **)&pval, palg);
    if (ptype != V_ASN1_SEQUENCE) {
        GOSTerr(GOST_F_DECODE_GOST_ALGOR_PARAMS,
                GOST_R_BAD_KEY_PARAMETERS_FORMAT);
        return 0;
    }
    p = pval->data;
    pkey_nid = OBJ_obj2nid(palg_obj);

    gkp = d2i_GOST_KEY_PARAMS(NULL, &p, pval->length);
    if (!gkp) {
        GOSTerr(GOST_F_DECODE_GOST_ALGOR_PARAMS,
                GOST_R_BAD_PKEY_PARAMETERS_FORMAT);
        return 0;
    }
    param_nid = OBJ_obj2nid(gkp->key_params);
    GOST_KEY_PARAMS_free(gkp);
    if (!EVP_PKEY_set_type(pkey, pkey_nid)) {
        GOSTerr(GOST_F_DECODE_GOST_ALGOR_PARAMS, ERR_R_INTERNAL_ERROR);
        return 0;
    }
    return gost_decode_nid_params(pkey, pkey_nid, param_nid);
}

static int gost_set_priv_key(EVP_PKEY *pkey, BIGNUM *priv)
{
    switch (EVP_PKEY_base_id(pkey)) {
    case NID_id_GostR3410_2012_512:
    case NID_id_GostR3410_2012_256:
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
        {
            EC_KEY *ec = EVP_PKEY_get0(pkey);
            if (!ec) {
                ec = EC_KEY_new();
                EVP_PKEY_assign(pkey, EVP_PKEY_base_id(pkey), ec);
            }
            if (!EC_KEY_set_private_key(ec, priv))
                return 0;
            if (!EVP_PKEY_missing_parameters(pkey))
                return gost_ec_compute_public(ec);
            break;
        }
    default:
        return 0;
    }
    return 1;
}

BIGNUM *gost_get0_priv_key(const EVP_PKEY *pkey)
{
    switch (EVP_PKEY_base_id(pkey)) {
    case NID_id_GostR3410_2012_512:
    case NID_id_GostR3410_2012_256:
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
        {
            EC_KEY *ec = EVP_PKEY_get0((EVP_PKEY *)pkey);
            if (ec)
                return (BIGNUM *)EC_KEY_get0_private_key(ec);
            break;
        }
    }
    return NULL;
}

/*
 * GOST CMS processing functions
 */
/* FIXME reaarange declarations */
static int pub_decode_gost_ec(EVP_PKEY *pk, const X509_PUBKEY *pub);

static int gost_cms_set_kari_shared_info(EVP_PKEY_CTX *pctx, CMS_RecipientInfo *ri)
{
	int ret = 0;
	X509_ALGOR *alg;
	ASN1_OCTET_STRING *ukm;

	/* Deal with originator */
	X509_ALGOR *pubalg = NULL;
	ASN1_BIT_STRING *pubkey = NULL;

	EVP_PKEY *peer_key = NULL;
	X509_PUBKEY *tmp   = NULL;

	int nid;
	unsigned char shared_key[64];
	size_t shared_key_size = 64;
	const EVP_CIPHER *cipher = NULL;

	if (CMS_RecipientInfo_kari_get0_alg(ri, &alg, &ukm) == 0)
		goto err;

	if (CMS_RecipientInfo_kari_get0_orig_id(ri, &pubalg, &pubkey, NULL, NULL, NULL) == 0)
		  goto err;

	nid = OBJ_obj2nid(alg->algorithm);
	if (alg->parameter->type != V_ASN1_SEQUENCE)
		  goto err;

	switch (nid) {
		case NID_kuznyechik_kexp15:
		case NID_magma_kexp15:
			cipher = EVP_get_cipherbynid(nid);
			break;
	}

	if (cipher == NULL) {
			GOSTerr(GOST_F_GOST_CMS_SET_KARI_SHARED_INFO, GOST_R_CIPHER_NOT_FOUND);
		  goto err;
  }

	if (EVP_PKEY_CTX_ctrl(pctx, -1, -1, EVP_PKEY_CTRL_SET_IV,
		ASN1_STRING_length(ukm), (void *)ASN1_STRING_get0_data(ukm)) <= 0)
			goto err;

	if (pubkey != NULL && pubalg != NULL) {
		const ASN1_OBJECT *paobj = NULL;
		int ptype = 0;
		const void *param = NULL;

		peer_key = EVP_PKEY_new();
		tmp = X509_PUBKEY_new();

		if ((peer_key == NULL) || (tmp == NULL)) {
			GOSTerr(GOST_F_GOST_CMS_SET_KARI_SHARED_INFO, ERR_R_MALLOC_FAILURE);
			goto err;
		}

		X509_ALGOR_get0(&paobj, &ptype, &param, pubalg);

		if (X509_PUBKEY_set0_param(tmp, (ASN1_OBJECT *)paobj,
			ptype, (void *)param,
			(unsigned char *)ASN1_STRING_get0_data(pubkey),
			ASN1_STRING_length(pubkey) ) == 0) {
				GOSTerr(GOST_F_GOST_CMS_SET_KARI_SHARED_INFO, GOST_R_PUBLIC_KEY_UNDEFINED);
				goto err;
		}

		if (pub_decode_gost_ec(peer_key, tmp) <= 0) {
				GOSTerr(GOST_F_GOST_CMS_SET_KARI_SHARED_INFO, GOST_R_ERROR_DECODING_PUBLIC_KEY);
				goto err;
		}

		if (EVP_PKEY_derive_set_peer(pctx, peer_key) <= 0) {
				GOSTerr(GOST_F_GOST_CMS_SET_KARI_SHARED_INFO, GOST_R_ERROR_SETTING_PEER_KEY);
				goto err;
		}
	}

	if (EVP_PKEY_derive(pctx, shared_key, &shared_key_size) <= 0) {
		GOSTerr(GOST_F_GOST_CMS_SET_KARI_SHARED_INFO, GOST_R_ERROR_COMPUTING_SHARED_KEY);
		goto err;
	}

	EVP_CIPHER_CTX_set_flags(CMS_RecipientInfo_kari_get0_ctx(ri), EVP_CIPHER_CTX_FLAG_WRAP_ALLOW);
	if (EVP_DecryptInit_ex(CMS_RecipientInfo_kari_get0_ctx(ri), cipher, NULL,
		shared_key, ukm->data+24) == 0)
			goto err;

	ret = 1;
err:
	EVP_PKEY_free(peer_key);
	if (ret == 0) {
		X509_PUBKEY_free(tmp);
	}

	return ret;
}

static int gost_cms_set_ktri_shared_info(EVP_PKEY_CTX *pctx, CMS_RecipientInfo *ri)
{
	X509_ALGOR *alg;
	struct gost_pmeth_data *gctx = EVP_PKEY_CTX_get_data(pctx);

	CMS_RecipientInfo_ktri_get0_algs(ri, NULL, NULL, &alg);

	switch (OBJ_obj2nid(alg->algorithm)) {
		case NID_kuznyechik_kexp15:
			gctx->cipher_nid = NID_kuznyechik_ctr;
			break;

		case NID_magma_kexp15:
			gctx->cipher_nid = NID_magma_ctr;
			break;

		case NID_id_GostR3410_2001:
		case NID_id_GostR3410_2001DH:
		case NID_id_GostR3410_2012_256:
		case NID_id_GostR3410_2012_512:
			gctx->cipher_nid = NID_id_Gost28147_89;
			break;

		default:
			GOSTerr(GOST_F_GOST_CMS_SET_KTRI_SHARED_INFO, GOST_R_UNSUPPORTED_RECIPIENT_INFO);
			return 0;
	}

	return 1;
}

static int gost_cms_set_shared_info(EVP_PKEY_CTX *pctx, CMS_RecipientInfo *ri)
{
	switch(CMS_RecipientInfo_type(ri)) {
		case CMS_RECIPINFO_AGREE:
			return gost_cms_set_kari_shared_info(pctx, ri);
		break;
		case CMS_RECIPINFO_TRANS:
			return gost_cms_set_ktri_shared_info(pctx, ri);
		break;
	}

	GOSTerr(GOST_F_GOST_CMS_SET_SHARED_INFO, GOST_R_UNSUPPORTED_RECIPIENT_INFO);
	return 0;
}

static ASN1_STRING *gost_encode_cms_params(int ka_nid)
{
	ASN1_STRING *ret = NULL;
	ASN1_STRING *params = ASN1_STRING_new();

	/* It's a hack. We have only one OID here, so we can use
	 * GOST_KEY_PARAMS which is a sequence of 3 OIDs,
	 * the 1st one is mandatory and the rest are optional */
	GOST_KEY_PARAMS *gkp = GOST_KEY_PARAMS_new();

	if (params == NULL || gkp == NULL) {
		  GOSTerr(GOST_F_GOST_ENCODE_CMS_PARAMS, ERR_R_MALLOC_FAILURE);
			goto end;
	}

	gkp->key_params = OBJ_nid2obj(ka_nid);
	params->length = i2d_GOST_KEY_PARAMS(gkp, &params->data);

	if (params->length < 0) {
		  GOSTerr(GOST_F_GOST_ENCODE_CMS_PARAMS, ERR_R_MALLOC_FAILURE);
			goto end;
	}

	params->type = V_ASN1_SEQUENCE;
	ret = params;

end:
	GOST_KEY_PARAMS_free(gkp);

	if (ret == NULL)
		ASN1_STRING_free(params);

	return ret;
}

/*
 * Control function
 */
static int pkey_ctrl_gost(EVP_PKEY *pkey, int op, long arg1, void *arg2)
{
    int nid = EVP_PKEY_base_id(pkey), md_nid = NID_undef;
    X509_ALGOR *alg1 = NULL, *alg2 = NULL;

    switch (nid) {
    case NID_id_GostR3410_2012_512:
        md_nid = NID_id_GostR3411_2012_512;
        break;
    case NID_id_GostR3410_2012_256:
        md_nid = NID_id_GostR3411_2012_256;
        break;
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
    case NID_id_GostR3410_94:
        md_nid = NID_id_GostR3411_94;
        break;
    default:
        return -1;
    }

    switch (op) {
    case ASN1_PKEY_CTRL_PKCS7_SIGN:
        if (arg1 == 0) {
            PKCS7_SIGNER_INFO_get0_algs((PKCS7_SIGNER_INFO *)arg2, NULL,
                                        &alg1, &alg2);
            X509_ALGOR_set0(alg1, OBJ_nid2obj(md_nid), V_ASN1_NULL, 0);
            X509_ALGOR_set0(alg2, OBJ_nid2obj(nid), V_ASN1_NULL, 0);
        }
        return 1;
#ifndef OPENSSL_NO_CMS
    case ASN1_PKEY_CTRL_CMS_SIGN:
        if (arg1 == 0) {
            CMS_SignerInfo_get0_algs((CMS_SignerInfo *)arg2, NULL, NULL,
                                     &alg1, &alg2);
            X509_ALGOR_set0(alg1, OBJ_nid2obj(md_nid), V_ASN1_NULL, 0);
            X509_ALGOR_set0(alg2, OBJ_nid2obj(nid), V_ASN1_NULL, 0);
        }
        return 1;
#endif
    case ASN1_PKEY_CTRL_PKCS7_ENCRYPT:
        if (arg1 == 0) { /* Encryption */
            ASN1_STRING *params = encode_gost_algor_params(pkey);
            if (!params) {
                return -1;
            }
            PKCS7_RECIP_INFO_get0_alg((PKCS7_RECIP_INFO *)arg2, &alg1);
            X509_ALGOR_set0(alg1, OBJ_nid2obj(EVP_PKEY_id(pkey)),
                            V_ASN1_SEQUENCE, params);
				}
        return 1;
#ifndef OPENSSL_NO_CMS
    case ASN1_PKEY_CTRL_CMS_ENVELOPE:
        if (arg1 == 0) {
          EVP_PKEY_CTX *pctx;
          CMS_RecipientInfo *ri = arg2;

          struct gost_pmeth_data *gctx = NULL;
          ASN1_STRING *params = NULL;

          pctx = CMS_RecipientInfo_get0_pkey_ctx(ri);
          if (!pctx)
            return 0;

          gctx = EVP_PKEY_CTX_get_data(pctx);

          switch (gctx->cipher_nid) {
            case NID_magma_ctr:
            case NID_kuznyechik_ctr:
              {
                int ka_nid;

                nid = (gctx->cipher_nid == NID_magma_ctr) ? NID_magma_kexp15 :
                  NID_kuznyechik_kexp15;

                ka_nid = (EVP_PKEY_base_id(pkey) == NID_id_GostR3410_2012_256) ?
                  NID_id_tc26_agreement_gost_3410_2012_256 : NID_id_tc26_agreement_gost_3410_2012_512;

                params = gost_encode_cms_params(ka_nid);
              }
              break;
            default:
                params = encode_gost_algor_params(pkey);
              break;
          }

          if (params == NULL)
              return -1;

          CMS_RecipientInfo_ktri_get0_algs((CMS_RecipientInfo *)arg2, NULL,
              NULL, &alg1);
          X509_ALGOR_set0(alg1, OBJ_nid2obj(nid), V_ASN1_SEQUENCE, params);
        } else {
          EVP_PKEY_CTX *pctx;
          CMS_RecipientInfo *ri = arg2;
          pctx = CMS_RecipientInfo_get0_pkey_ctx(ri);
          if (!pctx)
              return 0;
          return gost_cms_set_shared_info(pctx, ri);
        }
        return 1;
#ifdef ASN1_PKEY_CTRL_CMS_RI_TYPE
  case ASN1_PKEY_CTRL_CMS_RI_TYPE:
        *(int *)arg2 = CMS_RECIPINFO_TRANS;
        return 1;
	case ASN1_PKEY_CTRL_CMS_IS_RI_TYPE_SUPPORTED:
			if (arg1 == CMS_RECIPINFO_AGREE || arg1 == CMS_RECIPINFO_TRANS) {
          *(int *)arg2 = 1;
				  return 1;
      }
			else
				  return 0;
			break;
#endif
#endif
    case ASN1_PKEY_CTRL_DEFAULT_MD_NID:
        *(int *)arg2 = md_nid;
        return 2;
    }

    return -2;
}

/* --------------------- free functions * ------------------------------*/
static void pkey_free_gost_ec(EVP_PKEY *key)
{
    EC_KEY_free((EC_KEY *)EVP_PKEY_get0(key));
}

/* ------------------ private key functions  -----------------------------*/

static BIGNUM *unmask_priv_key(EVP_PKEY *pk,
                               const unsigned char *buf, int len, int num_masks)
{
    BIGNUM *pknum_masked = NULL, *q = NULL;
    const EC_KEY *key_ptr = (pk) ? EVP_PKEY_get0(pk) : NULL;
    const EC_GROUP *group = (key_ptr) ? EC_KEY_get0_group(key_ptr) : NULL;

    pknum_masked = BN_lebin2bn(buf, len, BN_secure_new());
    if (!pknum_masked)
        return NULL;

    if (num_masks > 0) {
        /*
         * XXX Remove sign by gost94
         */
        const unsigned char *p = buf + num_masks * len;

        q = BN_new();
        if (!q || !group || EC_GROUP_get_order(group, q, NULL) <= 0) {
            BN_free(pknum_masked);
            pknum_masked = NULL;
            goto end;
        }

        for (; p != buf; p -= len) {
            BIGNUM *mask = BN_lebin2bn(p, len, BN_secure_new());
            BN_CTX *ctx = BN_CTX_secure_new();

            BN_mod_mul(pknum_masked, pknum_masked, mask, q, ctx);

            BN_CTX_free(ctx);
            BN_free(mask);
        }
    }

 end:
    if (q)
        BN_free(q);
    return pknum_masked;
}

static int priv_decode_gost(EVP_PKEY *pk,
                            const PKCS8_PRIV_KEY_INFO *p8inf)
{
    const unsigned char *pkey_buf = NULL, *p = NULL;
    int priv_len = 0;
    BIGNUM *pk_num = NULL;
    int ret = 0;
    const X509_ALGOR *palg = NULL;
    const ASN1_OBJECT *palg_obj = NULL;
    ASN1_INTEGER *priv_key = NULL;
    int expected_key_len;

    if (!PKCS8_pkey_get0(&palg_obj, &pkey_buf, &priv_len, &palg, p8inf))
        return 0;
    p = pkey_buf;
    if (!decode_gost_algor_params(pk, palg)) {
        return 0;
    }

    expected_key_len = pkey_bits_gost(pk) > 0 ? pkey_bits_gost(pk) / 8 : 0;
    if (expected_key_len == 0) {
        GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
        return 0;
    }

    if (priv_len % expected_key_len == 0) {
        /* Key is not wrapped but masked */
        pk_num = unmask_priv_key(pk, pkey_buf, expected_key_len,
                                 priv_len / expected_key_len - 1);
    } else if (V_ASN1_OCTET_STRING == *p) {
        /* New format - Little endian octet string */
        ASN1_OCTET_STRING *s = d2i_ASN1_OCTET_STRING(NULL, &p, priv_len);
        if (!s || ((s->length != 32) && (s->length != 64))) {
            ASN1_STRING_free(s);
            GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
            return 0;
        }
        pk_num = BN_lebin2bn(s->data, s->length, BN_secure_new());
        ASN1_STRING_free(s);
    } else if (V_ASN1_INTEGER == *p) {
        priv_key = d2i_ASN1_INTEGER(NULL, &p, priv_len);
        if (!priv_key) {
            GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
            return 0;
        }
        pk_num = ASN1_INTEGER_to_BN(priv_key, BN_secure_new());
        ASN1_INTEGER_free(priv_key);
    } else if ((V_ASN1_SEQUENCE | V_ASN1_CONSTRUCTED) == *p) {
        MASKED_GOST_KEY *mgk = d2i_MASKED_GOST_KEY(NULL, &p, priv_len);

        if (!mgk) {
            GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
            return 0;
        }

        priv_len = mgk->masked_priv_key->length;
        if (priv_len % expected_key_len) {
            MASKED_GOST_KEY_free(mgk);
            GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
            return 0;
        }

        pk_num = unmask_priv_key(pk, mgk->masked_priv_key->data,
                                 expected_key_len,
                                 priv_len / expected_key_len - 1);
        MASKED_GOST_KEY_free(mgk);
    } else {
        GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
        return 0;
    }

    if (pk_num == NULL) {
        GOSTerr(GOST_F_PRIV_DECODE_GOST, EVP_R_DECODE_ERROR);
        return 0;
    }

    ret = gost_set_priv_key(pk, pk_num);
    BN_free(pk_num);
    return ret;
}

/* ----------------------------------------------------------------------*/
static int priv_encode_gost(PKCS8_PRIV_KEY_INFO *p8, const EVP_PKEY *pk)
{
    ASN1_OBJECT *algobj = OBJ_nid2obj(EVP_PKEY_base_id(pk));
    ASN1_STRING *params = NULL;
    unsigned char *buf = NULL;
    int key_len = pkey_bits_gost(pk), i = 0;
    /* unmasked private key */
    const char *pk_format = get_gost_engine_param(GOST_PARAM_PK_FORMAT);

    key_len = (key_len < 0) ? 0 : key_len / 8;
    if (key_len == 0 || !(buf = OPENSSL_secure_malloc(key_len))) {
        return 0;
    }

    if (!store_bignum(gost_get0_priv_key(pk), buf, key_len)) {
        OPENSSL_secure_free(buf);
        return 0;
    }

    params = encode_gost_algor_params(pk);
    if (!params) {
        OPENSSL_secure_free(buf);
        return 0;
    }

    /* Convert buf to Little-endian */
    for (i = 0; i < key_len / 2; i++) {
        unsigned char tmp = buf[i];
        buf[i] = buf[key_len - 1 - i];
        buf[key_len - 1 - i] = tmp;
    }

    if (pk_format != NULL && strcmp(pk_format, PK_WRAP_PARAM) == 0) {
        ASN1_STRING *octet = ASN1_STRING_new();
        int priv_len = 0;
        unsigned char *priv_buf = NULL;
        if (!octet || !ASN1_OCTET_STRING_set(octet, buf, key_len)) {
            ASN1_STRING_free(octet);
            ASN1_STRING_free(params);
            OPENSSL_secure_free(buf);
            return 0;
        }
        priv_len = i2d_ASN1_OCTET_STRING(octet, &priv_buf);
        ASN1_STRING_free(octet);
        OPENSSL_secure_free(buf);

        return PKCS8_pkey_set0(p8, algobj, 0, V_ASN1_SEQUENCE, params,
                               priv_buf, priv_len);
    }

    return PKCS8_pkey_set0(p8, algobj, 0, V_ASN1_SEQUENCE, params,
                           buf, key_len);
}

/* --------- printing keys --------------------------------*/
static int print_gost_priv(BIO *out, const EVP_PKEY *pkey, int indent)
{
    BIGNUM *key;

    if (!BIO_indent(out, indent, 128))
        return 0;
    BIO_printf(out, "Private key: ");
    key = gost_get0_priv_key(pkey);
    if (!key)
        BIO_printf(out, "<undefined>");
    else
        BN_print(out, key);
    BIO_printf(out, "\n");

    return 1;
}

static int print_gost_ec_pub(BIO *out, const EVP_PKEY *pkey, int indent)
{
    BN_CTX *ctx;
    BIGNUM *X, *Y;
    const EC_POINT *pubkey;
    const EC_GROUP *group;
    EC_KEY *key = (EC_KEY *)EVP_PKEY_get0((EVP_PKEY *)pkey);
    int ok = 0;

    ctx = BN_CTX_new();
    if (!ctx) {
        GOSTerr(GOST_F_PRINT_GOST_EC_PUB, ERR_R_MALLOC_FAILURE);
        return 0;
    }

    BN_CTX_start(ctx);
    X = BN_CTX_get(ctx);
    Y = BN_CTX_get(ctx);
    pubkey = (key) ? EC_KEY_get0_public_key(key) : NULL;
    group = (key) ? EC_KEY_get0_group(key) : NULL;
    if (!pubkey || !group)
        goto err;

    if (!EC_POINT_get_affine_coordinates(group, pubkey, X, Y, ctx)) {
        GOSTerr(GOST_F_PRINT_GOST_EC_PUB, ERR_R_EC_LIB);
        goto err;
    }
    if (!BIO_indent(out, indent, 128))
        goto err;
    BIO_printf(out, "Public key:\n");
    if (!BIO_indent(out, indent + 3, 128))
        goto err;
    BIO_printf(out, "X:");
    BN_print(out, X);
    BIO_printf(out, "\n");
    if (!BIO_indent(out, indent + 3, 128))
        goto err;
    BIO_printf(out, "Y:");
    BN_print(out, Y);
    BIO_printf(out, "\n");
    ok = 1;
 err:
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    return ok;
}

static int print_gost_ec_param(BIO *out, const EVP_PKEY *pkey, int indent)
{
    EC_KEY *ec = EVP_PKEY_get0((EVP_PKEY *)pkey);
    const EC_GROUP *group = (ec) ? EC_KEY_get0_group(ec) : NULL;
    int param_nid;

    if (!group)
        return 0;

    param_nid = EC_GROUP_get_curve_name(group);
    if (!BIO_indent(out, indent, 128))
        return 0;
    BIO_printf(out, "Parameter set: %s\n", OBJ_nid2ln(param_nid));

    return 1;
}

static int print_gost_ec(BIO *out, const EVP_PKEY *pkey, int indent,
                         ASN1_PCTX *pctx, int type)
{
    if (type == 2) {
        if (print_gost_priv(out, pkey, indent) == 0)
            return 0;
    }
    if (type >= 1) {
        if (print_gost_ec_pub(out, pkey, indent) == 0)
            return 0;
    }

    return print_gost_ec_param(out, pkey, indent);
}

static int param_print_gost_ec(BIO *out, const EVP_PKEY *pkey, int indent,
                               ASN1_PCTX *pctx)
{
    return print_gost_ec(out, pkey, indent, pctx, 0);
}

static int pub_print_gost_ec(BIO *out, const EVP_PKEY *pkey, int indent,
                             ASN1_PCTX *pctx)
{
    return print_gost_ec(out, pkey, indent, pctx, 1);
}

static int priv_print_gost_ec(BIO *out, const EVP_PKEY *pkey, int indent,
                              ASN1_PCTX *pctx)
{
    return print_gost_ec(out, pkey, indent, pctx, 2);
}

/* ---------------------------------------------------------------------*/
static int param_missing_gost_ec(const EVP_PKEY *pk)
{
    const EC_KEY *ec = EVP_PKEY_get0((EVP_PKEY *)pk);
    if (!ec)
        return 1;
    if (!EC_KEY_get0_group(ec))
        return 1;
    return 0;
}

static int param_copy_gost_ec(EVP_PKEY *to, const EVP_PKEY *from)
{
    EC_KEY *eto = EVP_PKEY_get0(to);
    const EC_KEY *efrom = EVP_PKEY_get0((EVP_PKEY *)from);
    if (EVP_PKEY_base_id(from) != EVP_PKEY_base_id(to)) {
        GOSTerr(GOST_F_PARAM_COPY_GOST_EC, GOST_R_INCOMPATIBLE_ALGORITHMS);
        return 0;
    }
    if (!efrom) {
        GOSTerr(GOST_F_PARAM_COPY_GOST_EC, GOST_R_KEY_PARAMETERS_MISSING);
        return 0;
    }
    if (!eto) {
        eto = EC_KEY_new();
        if (!eto) {
            GOSTerr(GOST_F_PARAM_COPY_GOST_EC, ERR_R_MALLOC_FAILURE);
            return 0;
        }
        if (!EVP_PKEY_assign(to, EVP_PKEY_base_id(from), eto)) {
            GOSTerr(GOST_F_PARAM_COPY_GOST_EC, ERR_R_INTERNAL_ERROR);
            EC_KEY_free(eto);
            return 0;
        }
    }
    if (!EC_KEY_set_group(eto, EC_KEY_get0_group(efrom))) {
        GOSTerr(GOST_F_PARAM_COPY_GOST_EC, ERR_R_INTERNAL_ERROR);
        return 0;
    }
    if (EC_KEY_get0_private_key(eto)) {
        return gost_ec_compute_public(eto);
    }
    return 1;
}

static int param_cmp_gost_ec(const EVP_PKEY *a, const EVP_PKEY *b)
{
    const EC_GROUP *group_a, *group_b;
    EC_KEY *ec_a = EVP_PKEY_get0((EVP_PKEY *)a);
    EC_KEY *ec_b = EVP_PKEY_get0((EVP_PKEY *)b);
    if (!ec_a || !ec_b)
        return 0;

    group_a = EC_KEY_get0_group(ec_a);
    group_b = EC_KEY_get0_group(ec_b);
    if (!group_a || !group_b)
        return 0;

    if (EC_GROUP_get_curve_name(group_a) == EC_GROUP_get_curve_name(group_b)) {
        return 1;
    }
    return 0;
}

/* ---------- Public key functions * --------------------------------------*/
static int pub_decode_gost_ec(EVP_PKEY *pk, const X509_PUBKEY *pub)
{
    X509_ALGOR *palg = NULL;
    const unsigned char *pubkey_buf = NULL;
    unsigned char *databuf = NULL;
    ASN1_OBJECT *palgobj = NULL;
    int pub_len;
    EC_POINT *pub_key = NULL;
    BIGNUM *X = NULL, *Y = NULL;
    ASN1_OCTET_STRING *octet = NULL;
    size_t len;
    const EC_GROUP *group;
    int retval = 0;

    if (!X509_PUBKEY_get0_param(&palgobj, &pubkey_buf, &pub_len, &palg, pub))
        goto ret;
    EVP_PKEY_assign(pk, OBJ_obj2nid(palgobj), NULL);
    if (!decode_gost_algor_params(pk, palg))
        goto ret;
    group = EC_KEY_get0_group(EVP_PKEY_get0(pk));
    octet = d2i_ASN1_OCTET_STRING(NULL, &pubkey_buf, pub_len);
    if (!octet) {
        GOSTerr(GOST_F_PUB_DECODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto ret;
    }
    databuf = OPENSSL_malloc(octet->length);
    if (!databuf) {
        GOSTerr(GOST_F_PUB_DECODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto ret;
    }

    BUF_reverse(databuf, octet->data, octet->length);
    len = octet->length / 2;

    Y = BN_bin2bn(databuf, len, NULL);
    X = BN_bin2bn(databuf + len, len, NULL);
    if (!X || !Y) {
        GOSTerr(GOST_F_PUB_DECODE_GOST_EC, ERR_R_BN_LIB);
        goto ret;
    }
    pub_key = EC_POINT_new(group);
    if (!EC_POINT_set_affine_coordinates(group, pub_key, X, Y, NULL)) {
        GOSTerr(GOST_F_PUB_DECODE_GOST_EC, ERR_R_EC_LIB);
        goto ret;
    }

    retval = EC_KEY_set_public_key(EVP_PKEY_get0(pk), pub_key);
    if (!retval)
        GOSTerr(GOST_F_PUB_DECODE_GOST_EC, ERR_R_EC_LIB);

ret:
    EC_POINT_free(pub_key);
    BN_free(X);
    BN_free(Y);
    OPENSSL_free(databuf);
    ASN1_OCTET_STRING_free(octet);
    return retval;
}

static int pub_encode_gost_ec(X509_PUBKEY *pub, const EVP_PKEY *pk)
{
    ASN1_OBJECT *algobj;
    ASN1_OCTET_STRING *octet = NULL;
    void *pval;
    unsigned char *buf = NULL, *databuf = NULL;
    int data_len, ret = -1;
    const EC_POINT *pub_key;
    BIGNUM *X = NULL, *Y = NULL, *order;
    const EC_KEY *ec = EVP_PKEY_get0((EVP_PKEY *)pk);
    int ptype = V_ASN1_SEQUENCE;
    ASN1_STRING *params;

    algobj = OBJ_nid2obj(EVP_PKEY_base_id(pk));

    params = encode_gost_algor_params(pk);
    pval = params;

    order = BN_new();
    if (order == NULL || EC_GROUP_get_order(EC_KEY_get0_group(ec), order, NULL) == 0) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto err;
    }
    if (EC_GROUP_get_order(EC_KEY_get0_group(ec), order, NULL) == 0) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_INTERNAL_ERROR);
        goto err;
    }
    pub_key = EC_KEY_get0_public_key(ec);
    if (!pub_key) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, GOST_R_PUBLIC_KEY_UNDEFINED);
        goto err;
    }
    X = BN_new();
    Y = BN_new();
    if (!X || !Y) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto err;
    }
    if (!EC_POINT_get_affine_coordinates(EC_KEY_get0_group(ec),
                                             pub_key, X, Y, NULL)) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_INTERNAL_ERROR);
        goto err;
    }
    data_len = 2 * BN_num_bytes(order);
    databuf = OPENSSL_zalloc(data_len);
    if (databuf == NULL) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    store_bignum(X, databuf + data_len / 2, data_len / 2);
    store_bignum(Y, databuf, data_len / 2);

    BUF_reverse(databuf, NULL, data_len);

    octet = ASN1_OCTET_STRING_new();
    if (octet == NULL) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (0 == ASN1_STRING_set(octet, databuf, data_len)) {
        GOSTerr(GOST_F_PUB_ENCODE_GOST_EC, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    ret = i2d_ASN1_OCTET_STRING(octet, &buf);
 err:
    ASN1_BIT_STRING_free(octet);
    if (X)
        BN_free(X);
    if (Y)
        BN_free(Y);
    if (order)
        BN_free(order);
    if (databuf)
        OPENSSL_free(databuf);

    if (ret < 0)
        return 0;
    return X509_PUBKEY_set0_param(pub, algobj, ptype, pval, buf, ret);
}

static int pub_cmp_gost_ec(const EVP_PKEY *a, const EVP_PKEY *b)
{
    const EC_KEY *ea = EVP_PKEY_get0((EVP_PKEY *)a);
    const EC_KEY *eb = EVP_PKEY_get0((EVP_PKEY *)b);
    const EC_POINT *ka, *kb;
    if (!ea || !eb)
        return 0;
    ka = EC_KEY_get0_public_key(ea);
    kb = EC_KEY_get0_public_key(eb);
    if (!ka || !kb)
        return 0;
    return (0 == EC_POINT_cmp(EC_KEY_get0_group(ea), ka, kb, NULL));
}

static int pkey_size_gost(const EVP_PKEY *pk)
{
    if (!pk)
        return -1;

    switch (EVP_PKEY_base_id(pk)) {
    case NID_id_GostR3410_94:
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
    case NID_id_GostR3410_2012_256:
        return 64;
    case NID_id_GostR3410_2012_512:
        return 128;
    }

    return -1;
}

/* ---------------------- ASN1 METHOD for GOST MAC  -------------------*/
static void mackey_free_gost(EVP_PKEY *pk)
{
    OPENSSL_free(EVP_PKEY_get0(pk));
}

static int mac_ctrl_gost(EVP_PKEY *pkey, int op, long arg1, void *arg2)
{
    switch (op) {
    case ASN1_PKEY_CTRL_DEFAULT_MD_NID:
        if (arg2) {
            *(int *)arg2 = NID_id_Gost28147_89_MAC;
            return 2;
        }
    }
    return -2;
}

static int mac_ctrl_gost_12(EVP_PKEY *pkey, int op, long arg1, void *arg2)
{
    switch (op) {
    case ASN1_PKEY_CTRL_DEFAULT_MD_NID:
        if (arg2) {
            *(int *)arg2 = NID_gost_mac_12;
            return 2;
        }
    }
    return -2;
}

static int mac_ctrl_magma(EVP_PKEY *pkey, int op, long arg1, void *arg2)
{
    switch (op) {
    case ASN1_PKEY_CTRL_DEFAULT_MD_NID:
        if (arg2) {
            *(int *)arg2 = NID_magma_mac;
            return 2;
        }
    }
    return -2;
}

static int mac_ctrl_grasshopper(EVP_PKEY *pkey, int op, long arg1, void *arg2)
{
    switch (op) {
    case ASN1_PKEY_CTRL_DEFAULT_MD_NID:
        if (arg2) {
            *(int *)arg2 = NID_grasshopper_mac;
            return 2;
        }
    }
    return -2;
}

static int gost2001_param_encode(const EVP_PKEY *pkey, unsigned char **pder)
{
    int nid =
        EC_GROUP_get_curve_name(EC_KEY_get0_group
                                (EVP_PKEY_get0((EVP_PKEY *)pkey)));
    return i2d_ASN1_OBJECT(OBJ_nid2obj(nid), pder);
}

static int gost2001_param_decode(EVP_PKEY *pkey, const unsigned char **pder,
                                 int derlen)
{
    ASN1_OBJECT *obj = NULL;
    int nid;
    if (d2i_ASN1_OBJECT(&obj, pder, derlen) == NULL) {
        return 0;
    }
    nid = OBJ_obj2nid(obj);
    ASN1_OBJECT_free(obj);

    return gost_decode_nid_params(pkey, NID_id_GostR3410_2001, nid);
}

/* ----------------------------------------------------------------------*/
int register_ameth_gost(int nid, EVP_PKEY_ASN1_METHOD **ameth,
                        const char *pemstr, const char *info)
{
    *ameth = EVP_PKEY_asn1_new(nid, ASN1_PKEY_SIGPARAM_NULL, pemstr, info);
    if (!*ameth)
        return 0;
    switch (nid) {
    case NID_id_GostR3410_2001:
    case NID_id_GostR3410_2001DH:
        EVP_PKEY_asn1_set_free(*ameth, pkey_free_gost_ec);
        EVP_PKEY_asn1_set_private(*ameth,
                                  priv_decode_gost, priv_encode_gost,
                                  priv_print_gost_ec);

        EVP_PKEY_asn1_set_param(*ameth,
                                gost2001_param_decode, gost2001_param_encode,
                                param_missing_gost_ec, param_copy_gost_ec,
                                param_cmp_gost_ec, param_print_gost_ec);
        EVP_PKEY_asn1_set_public(*ameth,
                                 pub_decode_gost_ec, pub_encode_gost_ec,
                                 pub_cmp_gost_ec, pub_print_gost_ec,
                                 pkey_size_gost, pkey_bits_gost);

        EVP_PKEY_asn1_set_ctrl(*ameth, pkey_ctrl_gost);
        EVP_PKEY_asn1_set_security_bits(*ameth, pkey_bits_gost);
        break;
    case NID_id_GostR3410_2012_256:
    case NID_id_GostR3410_2012_512:
        EVP_PKEY_asn1_set_free(*ameth, pkey_free_gost_ec);
        EVP_PKEY_asn1_set_private(*ameth,
                                  priv_decode_gost, priv_encode_gost,
                                  priv_print_gost_ec);

        EVP_PKEY_asn1_set_param(*ameth,
                                NULL, NULL,
                                param_missing_gost_ec, param_copy_gost_ec,
                                param_cmp_gost_ec, NULL);

        EVP_PKEY_asn1_set_public(*ameth,
                                 pub_decode_gost_ec, pub_encode_gost_ec,
                                 pub_cmp_gost_ec, pub_print_gost_ec,
                                 pkey_size_gost, pkey_bits_gost);

        EVP_PKEY_asn1_set_ctrl(*ameth, pkey_ctrl_gost);
        EVP_PKEY_asn1_set_security_bits(*ameth, pkey_bits_gost);
        break;
    case NID_id_Gost28147_89_MAC:
        EVP_PKEY_asn1_set_free(*ameth, mackey_free_gost);
        EVP_PKEY_asn1_set_ctrl(*ameth, mac_ctrl_gost);
        break;
    case NID_gost_mac_12:
        EVP_PKEY_asn1_set_free(*ameth, mackey_free_gost);
        EVP_PKEY_asn1_set_ctrl(*ameth, mac_ctrl_gost_12);
        break;
    case NID_magma_mac:
        EVP_PKEY_asn1_set_free(*ameth, mackey_free_gost);
        EVP_PKEY_asn1_set_ctrl(*ameth, mac_ctrl_magma);
        break;
    case NID_grasshopper_mac:
        EVP_PKEY_asn1_set_free(*ameth, mackey_free_gost);
        EVP_PKEY_asn1_set_ctrl(*ameth, mac_ctrl_grasshopper);
        break;
    }
    return 1;
}
