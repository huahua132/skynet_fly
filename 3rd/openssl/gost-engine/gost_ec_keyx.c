/**********************************************************************
 *                        gost_ec_keyx.c                              *
 *                                                                    *
 *             Copyright (c) 2005-2013 Cryptocom LTD                  *
 *   Copyright (c) 2018,2020 Dmitry Belyavskiy <beldmit@gmail.com>    *
 *   Copyright (c) 2020 Billy Brumley <bbrumley@gmail.com>            *
 *                                                                    *
 *         This file is distributed under the same license as OpenSSL *
 *                                                                    *
 *   VK0 R 50.1.113-2016 / RFC 7836                                   *
 *   KEG R 1323565.1.020-2018                                         *
 *   VK0 34.10-2001 key exchange and GOST R 34.10-2001 (RFC 4357)     *
 *   based PKCS7/SMIME support                                        *
 *          Requires OpenSSL 0.9.9 for compilation                    *
 **********************************************************************/
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/rand.h>
#include <string.h>
#include <openssl/objects.h>
#include "gost89.h"
#include "e_gost_err.h"
#include "gost_keywrap.h"
#include "gost_lcl.h"

/* Implementation of CryptoPro VKO 34.10-2001/2012 algorithm */
int VKO_compute_key(unsigned char *shared_key,
                    const EC_POINT *pub_key, const EC_KEY *priv_key,
                    const unsigned char *ukm, const size_t ukm_size,
                    const int vko_dgst_nid)
{
    unsigned char *databuf = NULL;
    BIGNUM *scalar = NULL, *X = NULL, *Y = NULL;
    const EC_GROUP *grp = NULL;
    EC_POINT *pnt = NULL;
    BN_CTX *ctx = NULL;
    EVP_MD_CTX *mdctx = NULL;
    const EVP_MD *md = NULL;
    int buf_len, half_len;
    int ret = 0;

    if ((ctx = BN_CTX_secure_new()) == NULL) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, ERR_R_MALLOC_FAILURE);
        return 0;
    }
    BN_CTX_start(ctx);

    md = EVP_get_digestbynid(vko_dgst_nid);
    if (!md) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, GOST_R_INVALID_DIGEST_TYPE);
        goto err;
    }

    grp = EC_KEY_get0_group(priv_key);
    scalar = BN_CTX_get(ctx);
    X = BN_CTX_get(ctx);

    if ((Y = BN_CTX_get(ctx)) == NULL
        || (pnt = EC_POINT_new(grp)) == NULL
        || BN_lebin2bn(ukm, ukm_size, scalar) == NULL
        || !BN_mod_mul(scalar, scalar, EC_KEY_get0_private_key(priv_key),
                       EC_GROUP_get0_order(grp), ctx))
        goto err;

#if 0
    /*-
     * These two curves have cofactor 4; the rest have cofactor 1.
     * But currently gost_ec_point_mul takes care of the cofactor clearing,
     * hence this code is not needed.
     */
    switch (EC_GROUP_get_curve_name(grp)) {
        case NID_id_tc26_gost_3410_2012_256_paramSetA:
        case NID_id_tc26_gost_3410_2012_512_paramSetC:
            if (!BN_lshift(scalar, scalar, 2))
                goto err;
            break;
    }
#endif

    if (!gost_ec_point_mul(grp, pnt, NULL, pub_key, scalar, ctx)) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, GOST_R_ERROR_POINT_MUL);
        goto err;
    }
    if (!EC_POINT_get_affine_coordinates(grp, pnt, X, Y, ctx)) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, ERR_R_EC_LIB);
        goto err;
    }

    half_len = BN_num_bytes(EC_GROUP_get0_field(grp));
    buf_len = 2 * half_len;
    if ((databuf = OPENSSL_malloc(buf_len)) == NULL) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    /*
     * Serialize elliptic curve point same way as we do it when saving key
     */
    if (BN_bn2lebinpad(X, databuf, half_len) != half_len
        || BN_bn2lebinpad(Y, databuf + half_len, half_len) != half_len)
        goto err;

    if ((mdctx = EVP_MD_CTX_new()) == NULL) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (EVP_MD_CTX_init(mdctx) == 0
        || EVP_DigestInit_ex(mdctx, md, NULL) == 0
        || EVP_DigestUpdate(mdctx, databuf, buf_len) == 0
        || EVP_DigestFinal_ex(mdctx, shared_key, NULL) == 0) {
        GOSTerr(GOST_F_VKO_COMPUTE_KEY, ERR_R_EVP_LIB);
        goto err;
    }

    ret = (EVP_MD_size(md) > 0) ? EVP_MD_size(md) : 0;

 err:
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    EC_POINT_free(pnt);
    EVP_MD_CTX_free(mdctx);
    OPENSSL_free(databuf);

    return ret;
}

/*
 * KEG Algorithm described in R 1323565.1.020-2018 6.4.5.1.
 * keyout expected to be 64 bytes
 * */
static int gost_keg(const unsigned char *ukm_source, int pkey_nid,
                    const EC_POINT *pub_key, const EC_KEY *priv_key,
                    unsigned char *keyout)
{
/* Adjust UKM */
    unsigned char real_ukm[16];
    size_t keylen = 0;

    memset(real_ukm, 0, 16);
    if (memcmp(ukm_source, real_ukm, 16) == 0)
        real_ukm[15] = 1;
    else {
        memcpy(real_ukm, ukm_source, 16);
        BUF_reverse(real_ukm, NULL, 16);
    }

    switch (pkey_nid) {
    case NID_id_GostR3410_2012_512:
        keylen =
            VKO_compute_key(keyout, pub_key, priv_key, real_ukm, 16,
                            NID_id_GostR3411_2012_512);
        return (keylen) ? keylen : 0;
        break;

    case NID_id_GostR3410_2012_256:
        {
            unsigned char tmpkey[32];
            keylen =
              VKO_compute_key(tmpkey, pub_key, priv_key, real_ukm, 16,
                  NID_id_GostR3411_2012_256);

            if (keylen == 0)
                return 0;

            if (gost_kdftree2012_256
                (keyout, 64, tmpkey, 32, (const unsigned char *)"kdf tree", 8,
                 ukm_source + 16, 8, 1) > 0)
                keylen = 64;
            else
                keylen = 0;

            OPENSSL_cleanse(tmpkey, 32);
            return (keylen) ? keylen : 0;
        }
    default:
        return 0;
    }
}

/*
 * EVP_PKEY_METHOD callback derive.
 * Implements VKO R 34.10-2001/2012 algorithms
 */
/*
 * Backend for EVP_PKEY_derive()
 * It have KEG mode (default) and VKO mode (enable by EVP_PKEY_CTRL_SET_VKO).
 */
int pkey_gost_ec_derive(EVP_PKEY_CTX *ctx, unsigned char *key, size_t *keylen)
{
    /*
     * Public key of peer in the ctx field peerkey
     * Our private key in the ctx pkey
     * ukm is in the algorithm specific context data
     */
    EVP_PKEY *my_key = EVP_PKEY_CTX_get0_pkey(ctx);
    EVP_PKEY *peer_key = EVP_PKEY_CTX_get0_peerkey(ctx);
    struct gost_pmeth_data *data = EVP_PKEY_CTX_get_data(ctx);
    int dgst_nid = NID_undef;

    if (!data || data->shared_ukm_size == 0) {
        GOSTerr(GOST_F_PKEY_GOST_EC_DERIVE, GOST_R_UKM_NOT_SET);
        return 0;
    }

    /* VKO */
    if (data->vko_dgst_nid) {
        if (!key) {
            *keylen = data->vko_dgst_nid == NID_id_GostR3411_2012_256? 32 : 64;
            return 1;
        }
        *keylen = VKO_compute_key(key,
                                  EC_KEY_get0_public_key(EVP_PKEY_get0(peer_key)),
                                  (EC_KEY *)EVP_PKEY_get0(my_key),
                                  data->shared_ukm, data->shared_ukm_size,
                                  data->vko_dgst_nid);
        return (*keylen) ? 1 : 0;
    }

    /*
     * shared_ukm_size = 8 stands for pre-2018 cipher suites
     * It means 32 bytes of key length, 8 byte UKM, 32-bytes hash
     *
     * shared_ukm_size = 32 stands for post-2018 cipher suites
     * It means 64 bytes of shared_key, 16 bytes of UKM and either
     * 64 bytes of hash or 64 bytes of TLSTREE output
     * */

    switch (data->shared_ukm_size) {
    case 8:
        {
            if (key == NULL) {
                *keylen = 32;
                return 1;
            }
            EVP_PKEY_get_default_digest_nid(my_key, &dgst_nid);
            if (dgst_nid == NID_id_GostR3411_2012_512)
                dgst_nid = NID_id_GostR3411_2012_256;

            *keylen =
                VKO_compute_key(key,
                                EC_KEY_get0_public_key(EVP_PKEY_get0(peer_key)),
                                (EC_KEY *)EVP_PKEY_get0(my_key),
                                data->shared_ukm, 8, dgst_nid);
            return (*keylen) ? 1 : 0;
        }
        break;
    case 32:
        {
            if (key == NULL) {
                *keylen = 64;
                return 1;
            }

            *keylen = gost_keg(data->shared_ukm, EVP_PKEY_id(my_key),
                               EC_KEY_get0_public_key(EVP_PKEY_get0(peer_key)),
                               (EC_KEY *)EVP_PKEY_get0(my_key), key);
            return (*keylen) ? 1 : 0;
        }

        break;
    default:
        return 0;
    }
}

/*
 * Generates ephemeral key based on pubk algorithm computes shared key using
 * VKO and returns filled up GOST_KEY_TRANSPORT structure
 */

/*
 * EVP_PKEY_METHOD callback encrypt
 * Implementation of GOST2001/12 key transport, cryptopro variation
 */

static int pkey_GOST_ECcp_encrypt(EVP_PKEY_CTX *pctx, unsigned char *out,
                           size_t *out_len, const unsigned char *key,
                           size_t key_len)
{
    GOST_KEY_TRANSPORT *gkt = NULL;
    EVP_PKEY *pubk = EVP_PKEY_CTX_get0_pkey(pctx);
    struct gost_pmeth_data *data = EVP_PKEY_CTX_get_data(pctx);
    int pkey_nid = EVP_PKEY_base_id(pubk);
    ASN1_OBJECT *crypt_params_obj = (pkey_nid == NID_id_GostR3410_2001 || pkey_nid == NID_id_GostR3410_2001DH) ?
        OBJ_nid2obj(NID_id_Gost28147_89_CryptoPro_A_ParamSet) :
        OBJ_nid2obj(NID_id_tc26_gost_28147_param_Z);
    const struct gost_cipher_info *param =
        get_encryption_params(crypt_params_obj);
    unsigned char ukm[8], shared_key[32], crypted_key[44];
    int ret = 0;
    int key_is_ephemeral = 1;
    gost_ctx cctx;
    EVP_PKEY *sec_key = EVP_PKEY_CTX_get0_peerkey(pctx);
    int res_len = 0;

    if (data->shared_ukm_size) {
        memcpy(ukm, data->shared_ukm, 8);
    } else {
        if (RAND_bytes(ukm, 8) <= 0) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT, GOST_R_RNG_ERROR);
            return 0;
        }
    }
    if (!param)
        goto err;
    /* Check for private key in the peer_key of context */
    if (sec_key) {
        key_is_ephemeral = 0;
        if (!gost_get0_priv_key(sec_key)) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT,
                    GOST_R_NO_PRIVATE_PART_OF_NON_EPHEMERAL_KEYPAIR);
            goto err;
        }
    } else {
        key_is_ephemeral = 1;
        if (out) {
            sec_key = EVP_PKEY_new();
            if (!EVP_PKEY_assign(sec_key, EVP_PKEY_base_id(pubk), EC_KEY_new())
                || !EVP_PKEY_copy_parameters(sec_key, pubk)
                || !gost_ec_keygen(EVP_PKEY_get0(sec_key))) {
                GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT,
                        GOST_R_ERROR_COMPUTING_SHARED_KEY);
                goto err;
            }
        }
    }
    if (out) {
        int dgst_nid = NID_undef;
        EVP_PKEY_get_default_digest_nid(pubk, &dgst_nid);
        if (dgst_nid == NID_id_GostR3411_2012_512)
            dgst_nid = NID_id_GostR3411_2012_256;

        if (!VKO_compute_key(shared_key,
                             EC_KEY_get0_public_key(EVP_PKEY_get0(pubk)),
                             EVP_PKEY_get0(sec_key), ukm, 8, dgst_nid)) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT,
                    GOST_R_ERROR_COMPUTING_SHARED_KEY);
            goto err;
        }
        gost_init(&cctx, param->sblock);
        keyWrapCryptoPro(&cctx, shared_key, ukm, key, crypted_key);
    }
    gkt = GOST_KEY_TRANSPORT_new();
    if (!gkt) {
        goto err;
    }
    if (!ASN1_OCTET_STRING_set(gkt->key_agreement_info->eph_iv, ukm, 8)) {
        goto err;
    }
    if (!ASN1_OCTET_STRING_set(gkt->key_info->imit, crypted_key + 40, 4)) {
        goto err;
    }
    if (!ASN1_OCTET_STRING_set
        (gkt->key_info->encrypted_key, crypted_key + 8, 32)) {
        goto err;
    }
    if (key_is_ephemeral) {
        if (!X509_PUBKEY_set
            (&gkt->key_agreement_info->ephem_key, out ? sec_key : pubk)) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT,
                    GOST_R_CANNOT_PACK_EPHEMERAL_KEY);
            goto err;
        }
    }
    ASN1_OBJECT_free(gkt->key_agreement_info->cipher);
    gkt->key_agreement_info->cipher = OBJ_nid2obj(param->nid);
    if (key_is_ephemeral)
        EVP_PKEY_free(sec_key);
    if (!key_is_ephemeral) {
        /* Set control "public key from client certificate used" */
        if (EVP_PKEY_CTX_ctrl(pctx, -1, -1, EVP_PKEY_CTRL_PEER_KEY, 3, NULL)
            <= 0) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT, GOST_R_CTRL_CALL_FAILED);
            goto err;
        }
    }
    res_len = i2d_GOST_KEY_TRANSPORT(gkt, NULL);
    if (res_len <= 0) {
        GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT, ERR_R_ASN1_LIB);
        goto err;
    }

    if (out == NULL) {
        *out_len = res_len;
        ret = 1;
    } else {
        if ((size_t)res_len > *out_len) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT, GOST_R_INVALID_BUFFER_SIZE);
            goto err;
        }
        if ((*out_len = i2d_GOST_KEY_TRANSPORT(gkt, &out)) > 0)
            ret = 1;
        else
            GOSTerr(GOST_F_PKEY_GOST_ECCP_ENCRYPT, ERR_R_ASN1_LIB);
    }

    OPENSSL_cleanse(shared_key, sizeof(shared_key));
    GOST_KEY_TRANSPORT_free(gkt);
    return ret;
 err:
    OPENSSL_cleanse(shared_key, sizeof(shared_key));
    if (key_is_ephemeral)
        EVP_PKEY_free(sec_key);
    GOST_KEY_TRANSPORT_free(gkt);
    return -1;
}

/*
 * EVP_PKEY_METHOD callback decrypt
 * Implementation of GOST2018 key transport
 */
static int pkey_gost2018_encrypt(EVP_PKEY_CTX *pctx, unsigned char *out,
                          size_t *out_len, const unsigned char *key,
                          size_t key_len)
{
    PSKeyTransport_gost *pst = NULL;
    EVP_PKEY *pubk = EVP_PKEY_CTX_get0_pkey(pctx);
    struct gost_pmeth_data *data = EVP_PKEY_CTX_get_data(pctx);
    int pkey_nid = EVP_PKEY_base_id(pubk);
    unsigned char expkeys[64];
    EVP_PKEY *sec_key = NULL;
    int ret = 0;
    int mac_nid = NID_undef;
    size_t mac_len = 0;
    int exp_len = 0, iv_len = 0;
    unsigned char *exp_buf = NULL;
    int key_is_ephemeral = 0;
    int res_len = 0;

    switch (data->cipher_nid) {
    case NID_magma_ctr:
        mac_nid = NID_magma_mac;
        mac_len = 8;
        iv_len = 4;
        break;
    case NID_grasshopper_ctr:
        mac_nid = NID_grasshopper_mac;
        mac_len = 16;
        iv_len = 8;
        break;
    default:
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, GOST_R_INVALID_CIPHER);
        return -1;
        break;
    }
    exp_len = key_len + mac_len;
    exp_buf = OPENSSL_malloc(exp_len);
    if (!exp_buf) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_MALLOC_FAILURE);
        return -1;
    }

    sec_key = EVP_PKEY_CTX_get0_peerkey(pctx);
    if (!sec_key)
    {
      sec_key = EVP_PKEY_new();
      if (sec_key == NULL) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_MALLOC_FAILURE );
        goto err;
      }

      if (!EVP_PKEY_assign(sec_key, EVP_PKEY_base_id(pubk), EC_KEY_new())
          || !EVP_PKEY_copy_parameters(sec_key, pubk)
          || !gost_ec_keygen(EVP_PKEY_get0(sec_key))) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT,
            GOST_R_ERROR_COMPUTING_SHARED_KEY);
        goto err;
      }
      key_is_ephemeral = 1;
    }

    if (data->shared_ukm_size == 0) {
        if (RAND_bytes(data->shared_ukm, 32) <= 0) {
            GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_INTERNAL_ERROR);
            goto err;
        }
        data->shared_ukm_size = 32;
    }

    if (gost_keg(data->shared_ukm, pkey_nid,
                 EC_KEY_get0_public_key(EVP_PKEY_get0(pubk)),
                 EVP_PKEY_get0(sec_key), expkeys) <= 0) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT,
                GOST_R_ERROR_COMPUTING_EXPORT_KEYS);
        goto err;
    }

    if (gost_kexp15(key, key_len, data->cipher_nid, expkeys + 32,
                    mac_nid, expkeys + 0, data->shared_ukm + 24, iv_len,
                    exp_buf, &exp_len) <= 0) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, GOST_R_CANNOT_PACK_EPHEMERAL_KEY);
        goto err;
    }

    pst = PSKeyTransport_gost_new();
    if (!pst) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    pst->ukm = ASN1_OCTET_STRING_new();
    if (pst->ukm == NULL) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (!ASN1_OCTET_STRING_set(pst->ukm, data->shared_ukm, data->shared_ukm_size)) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (!ASN1_OCTET_STRING_set(pst->psexp, exp_buf, exp_len)) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    if (!X509_PUBKEY_set(&pst->ephem_key, out ? sec_key : pubk)) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, GOST_R_CANNOT_PACK_EPHEMERAL_KEY);
        goto err;
    }

    res_len = i2d_PSKeyTransport_gost(pst, NULL);
    if (res_len <= 0) {
        GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_ASN1_LIB);
        goto err;
    }

    if (out == NULL) {
        *out_len = res_len;
        ret = 1;
    } else {
        if ((size_t)res_len > *out_len) {
            GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, GOST_R_INVALID_BUFFER_SIZE);
            goto err;
        }
        if ((*out_len = i2d_PSKeyTransport_gost(pst, &out)) > 0)
            ret = 1;
        else
            GOSTerr(GOST_F_PKEY_GOST2018_ENCRYPT, ERR_R_ASN1_LIB);
    }

 err:
    OPENSSL_cleanse(expkeys, sizeof(expkeys));
    if (key_is_ephemeral)
        EVP_PKEY_free(sec_key);

    PSKeyTransport_gost_free(pst);
    OPENSSL_free(exp_buf);
    return ret;
}

int pkey_gost_encrypt(EVP_PKEY_CTX *pctx, unsigned char *out,
                      size_t *out_len, const unsigned char *key, size_t key_len)
{
  struct gost_pmeth_data *gctx = EVP_PKEY_CTX_get_data(pctx);
  switch (gctx->cipher_nid)
  {
    case NID_id_Gost28147_89:
    case NID_undef: /* FIXME */
      return pkey_GOST_ECcp_encrypt(pctx, out, out_len, key, key_len);
      break;
    case NID_kuznyechik_ctr:
    case NID_magma_ctr:
      return pkey_gost2018_encrypt(pctx, out, out_len, key, key_len);
      break;
    default:
      GOSTerr(GOST_F_PKEY_GOST_ENCRYPT, ERR_R_INTERNAL_ERROR);
      return -1;
  }
}

/*
 * EVP_PKEY_METHOD callback decrypt
 * Implementation of GOST2001/12 key transport, cryptopro variation
 */
static int pkey_GOST_ECcp_decrypt(EVP_PKEY_CTX *pctx, unsigned char *key,
                           size_t *key_len, const unsigned char *in,
                           size_t in_len)
{
    const unsigned char *p = in;
    EVP_PKEY *priv = EVP_PKEY_CTX_get0_pkey(pctx);
    GOST_KEY_TRANSPORT *gkt = NULL;
    int ret = 0;
    unsigned char wrappedKey[44];
    unsigned char sharedKey[32];
    gost_ctx ctx;
    const struct gost_cipher_info *param = NULL;
    EVP_PKEY *eph_key = NULL, *peerkey = NULL;
    int dgst_nid = NID_undef;

    gkt = d2i_GOST_KEY_TRANSPORT(NULL, (const unsigned char **)&p, in_len);
    if (!gkt) {
        GOSTerr(GOST_F_PKEY_GOST_ECCP_DECRYPT,
                GOST_R_ERROR_PARSING_KEY_TRANSPORT_INFO);
        return -1;
    }

    /* If key transport structure contains public key, use it */
    eph_key = X509_PUBKEY_get(gkt->key_agreement_info->ephem_key);
    if (eph_key) {
        if (EVP_PKEY_derive_set_peer(pctx, eph_key) <= 0) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_DECRYPT,
                    GOST_R_INCOMPATIBLE_PEER_KEY);
            goto err;
        }
    } else {
        /* Set control "public key from client certificate used" */
        if (EVP_PKEY_CTX_ctrl(pctx, -1, -1, EVP_PKEY_CTRL_PEER_KEY, 3, NULL)
            <= 0) {
            GOSTerr(GOST_F_PKEY_GOST_ECCP_DECRYPT, GOST_R_CTRL_CALL_FAILED);
            goto err;
        }
    }
    peerkey = EVP_PKEY_CTX_get0_peerkey(pctx);
    if (!peerkey) {
        GOSTerr(GOST_F_PKEY_GOST_ECCP_DECRYPT, GOST_R_NO_PEER_KEY);
        goto err;
    }

    param = get_encryption_params(gkt->key_agreement_info->cipher);
    if (!param) {
        goto err;
    }

    gost_init(&ctx, param->sblock);
    OPENSSL_assert(gkt->key_agreement_info->eph_iv->length == 8);
    memcpy(wrappedKey, gkt->key_agreement_info->eph_iv->data, 8);
    OPENSSL_assert(gkt->key_info->encrypted_key->length == 32);
    memcpy(wrappedKey + 8, gkt->key_info->encrypted_key->data, 32);
    OPENSSL_assert(gkt->key_info->imit->length == 4);
    memcpy(wrappedKey + 40, gkt->key_info->imit->data, 4);

    EVP_PKEY_get_default_digest_nid(priv, &dgst_nid);
    if (dgst_nid == NID_id_GostR3411_2012_512)
        dgst_nid = NID_id_GostR3411_2012_256;

    if (!VKO_compute_key(sharedKey,
                         EC_KEY_get0_public_key(EVP_PKEY_get0(peerkey)),
                         EVP_PKEY_get0(priv), wrappedKey, 8, dgst_nid)) {
        GOSTerr(GOST_F_PKEY_GOST_ECCP_DECRYPT,
                GOST_R_ERROR_COMPUTING_SHARED_KEY);
        goto err;
    }
    if (!keyUnwrapCryptoPro(&ctx, sharedKey, wrappedKey, key)) {
        GOSTerr(GOST_F_PKEY_GOST_ECCP_DECRYPT,
                GOST_R_ERROR_COMPUTING_SHARED_KEY);
        goto err;
    }

    *key_len = 32;
    ret = 1;
 err:
    OPENSSL_cleanse(sharedKey, sizeof(sharedKey));
    EVP_PKEY_free(eph_key);
    GOST_KEY_TRANSPORT_free(gkt);
    return ret;
}

/*
 * EVP_PKEY_METHOD callback decrypt
 * Implementation of GOST2018 key transport
 */
static int pkey_gost2018_decrypt(EVP_PKEY_CTX *pctx, unsigned char *key,
                          size_t *key_len, const unsigned char *in,
                          size_t in_len)
{
    const unsigned char *p = in;
    struct gost_pmeth_data *data;
    EVP_PKEY *priv;
    PSKeyTransport_gost *pst = NULL;
    int ret = 0;
    unsigned char expkeys[64];
    EVP_PKEY *eph_key = NULL;
    int pkey_nid;
    int mac_nid = NID_undef;
    int iv_len = 0;

    if (!(data = EVP_PKEY_CTX_get_data(pctx)) ||
        !(priv = EVP_PKEY_CTX_get0_pkey(pctx))) {
       GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT, GOST_R_ERROR_COMPUTING_EXPORT_KEYS);
       ret = 0;
       goto err;
    }
    pkey_nid = EVP_PKEY_base_id(priv);

    switch (data->cipher_nid) {
    case NID_magma_ctr:
        mac_nid = NID_magma_mac;
        iv_len = 4;
        break;
    case NID_grasshopper_ctr:
        mac_nid = NID_grasshopper_mac;
        iv_len = 8;
        break;
    default:
        GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT, GOST_R_INVALID_CIPHER);
        return -1;
        break;
    }

    pst = d2i_PSKeyTransport_gost(NULL, (const unsigned char **)&p, in_len);
    if (!pst) {
        GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT,
                GOST_R_ERROR_PARSING_KEY_TRANSPORT_INFO);
        return -1;
    }

    eph_key = X509_PUBKEY_get(pst->ephem_key);
/*
 * TODO beldmit
   1.  Checks the next three conditions fulfilling and terminates the
   connection with fatal error if not.

   o  Q_eph is on the same curve as server public key;

   o  Q_eph is not equal to zero point;

   o  q * Q_eph is not equal to zero point.
*/
    if (eph_key == NULL) {
       GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT,
               GOST_R_ERROR_COMPUTING_EXPORT_KEYS);
       ret = 0;
       goto err;
    }

    if (data->shared_ukm_size == 0 && pst->ukm != NULL) {
        if (EVP_PKEY_CTX_ctrl(pctx, -1, -1, EVP_PKEY_CTRL_SET_IV,
        ASN1_STRING_length(pst->ukm), (void *)ASN1_STRING_get0_data(pst->ukm)) < 0) {
            GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT, GOST_R_UKM_NOT_SET);
            goto err;
        }
    }

    if (gost_keg(data->shared_ukm, pkey_nid,
                 EC_KEY_get0_public_key(EVP_PKEY_get0(eph_key)),
                 EVP_PKEY_get0(priv), expkeys) <= 0) {
        GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT,
                GOST_R_ERROR_COMPUTING_EXPORT_KEYS);
        goto err;
    }

    if (gost_kimp15(ASN1_STRING_get0_data(pst->psexp),
                    ASN1_STRING_length(pst->psexp), data->cipher_nid,
                    expkeys + 32, mac_nid, expkeys + 0, data->shared_ukm + 24,
                    iv_len, key) <= 0) {
        GOSTerr(GOST_F_PKEY_GOST2018_DECRYPT, GOST_R_CANNOT_UNPACK_EPHEMERAL_KEY);
        goto err;
    }

    *key_len = 32;
    ret = 1;
 err:
    OPENSSL_cleanse(expkeys, sizeof(expkeys));
    EVP_PKEY_free(eph_key);
    PSKeyTransport_gost_free(pst);
    return ret;
}

int pkey_gost_decrypt(EVP_PKEY_CTX *pctx, unsigned char *key,
                      size_t *key_len, const unsigned char *in, size_t in_len)
{
    struct gost_pmeth_data *gctx = EVP_PKEY_CTX_get_data(pctx);

    if (key == NULL) {
        *key_len = 32;
        return 1;
    }

    if (key != NULL && *key_len < 32) {
        GOSTerr(GOST_F_PKEY_GOST_DECRYPT, GOST_R_INVALID_BUFFER_SIZE);
        return 0;
    }

    switch (gctx->cipher_nid)
    {
        case NID_id_Gost28147_89:
        case NID_undef: /* FIXME */
            return pkey_GOST_ECcp_decrypt(pctx, key, key_len, in, in_len);
        case NID_kuznyechik_ctr:
        case NID_magma_ctr:
            return pkey_gost2018_decrypt(pctx, key, key_len, in, in_len);
        default:
      GOSTerr(GOST_F_PKEY_GOST_DECRYPT, ERR_R_INTERNAL_ERROR);
      return -1;
    }
}
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
