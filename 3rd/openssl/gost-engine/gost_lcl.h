#ifndef GOST_TOOLS_H
# define GOST_TOOLS_H
/**********************************************************************
 *                        gost_lcl.h                                  *
 *             Copyright (c) 2006 Cryptocom LTD                       *
 *             Copyright (c) 2020 Vitaly Chikunov <vt@altlinux.org>   *
 *       This file is distributed under the same license as OpenSSL   *
 *                                                                    *
 *         Internal declarations  used in GOST engine                 *
 *         OpenSSL 0.9.9 libraries required to compile and use        *
 *                              this code                             *
 **********************************************************************/
# include <openssl/core.h>
# include <openssl/bn.h>
# include <openssl/evp.h>
# include <openssl/asn1t.h>
# include <openssl/x509.h>
# include <openssl/engine.h>
# include <openssl/ec.h>
# include <openssl/asn1.h>
# include "gost89.h"
# include "gosthash.h"
/* Control commands */
# define GOST_PARAM_CRYPT_PARAMS 0
# define GOST_PARAM_PBE_PARAMS 1
# define GOST_PARAM_PK_FORMAT 2
# define GOST_PARAM_MAX 3
# define GOST_CTRL_CRYPT_PARAMS (ENGINE_CMD_BASE+GOST_PARAM_CRYPT_PARAMS)
# define GOST_CTRL_PBE_PARAMS   (ENGINE_CMD_BASE+GOST_PARAM_PBE_PARAMS)
# define GOST_CTRL_PK_FORMAT   (ENGINE_CMD_BASE+GOST_PARAM_PK_FORMAT)

typedef struct R3410_ec {
    int nid;
    char *a;
    char *b;
    char *p;
    char *q;
    char *x;
    char *y;
    char *cofactor;
    EC_GROUP *group;
} R3410_ec_params;

extern R3410_ec_params R3410_2001_paramset[],
    *R3410_2012_256_paramset, R3410_2012_512_paramset[];

void free_cached_groups(void);

extern const ENGINE_CMD_DEFN gost_cmds[];
int gost_control_func(ENGINE *e, int cmd, long i, void *p, void (*f) (void));
const char *get_gost_engine_param(int param);
int gost_set_default_param(int param, const char *value);
void gost_param_free(void);

/* method registration */

/* Provider implementation data */
extern const OSSL_ALGORITHM GOST_prov_macs[];
void GOST_prov_deinit_mac_digests(void);

int register_ameth_gost(int nid, EVP_PKEY_ASN1_METHOD **ameth,
                        const char *pemstr, const char *info);
int register_pmeth_gost(int id, EVP_PKEY_METHOD **pmeth, int flags);

/* Gost-specific pmeth control-function parameters */
/* For GOST R34.10 parameters */
# define param_ctrl_string "paramset"
# define ukm_ctrl_string "ukmhex"
# define vko_ctrl_string "vko"
# define EVP_PKEY_CTRL_GOST_PARAMSET (EVP_PKEY_ALG_CTRL+1)
/* For GOST 28147 MAC */
# define key_ctrl_string "key"
# define hexkey_ctrl_string "hexkey"
# define maclen_ctrl_string "size"
# define EVP_PKEY_CTRL_GOST_MAC_HEXKEY (EVP_PKEY_ALG_CTRL+3)
# define EVP_PKEY_CTRL_MAC_LEN (EVP_PKEY_ALG_CTRL+5)
# define EVP_PKEY_CTRL_SET_VKO (EVP_PKEY_ALG_CTRL+11)
/* Pmeth internal representation */
struct gost_pmeth_data {
    int sign_param_nid;         /* Should be set whenever parameters are
                                 * filled */
    EVP_MD *md;
    unsigned char shared_ukm[32];
    size_t shared_ukm_size;
    int peer_key_used;
    int cipher_nid;             /* KExp15/KImp15 algs */
    int vko_dgst_nid;
};

struct gost_mac_pmeth_data {
    short int key_set;
    short int mac_size;
    int mac_param_nid;
    EVP_MD *md;
    unsigned char key[32];
};

struct gost_mac_key {
    int mac_param_nid;
    unsigned char key[32];
    short int mac_size;
};
/* GOST-specific ASN1 structures */

typedef struct {
    ASN1_OCTET_STRING *encrypted_key;
    ASN1_OCTET_STRING *imit;
} GOST_KEY_INFO;

DECLARE_ASN1_FUNCTIONS(GOST_KEY_INFO)

typedef struct {
    ASN1_OBJECT *cipher;
    X509_PUBKEY *ephem_key;
    ASN1_OCTET_STRING *eph_iv;
} GOST_KEY_AGREEMENT_INFO;

DECLARE_ASN1_FUNCTIONS(GOST_KEY_AGREEMENT_INFO)

typedef struct {
    GOST_KEY_INFO *key_info;
    GOST_KEY_AGREEMENT_INFO *key_agreement_info;
} GOST_KEY_TRANSPORT;

DECLARE_ASN1_FUNCTIONS(GOST_KEY_TRANSPORT)

typedef struct {                /* FIXME incomplete */
    GOST_KEY_TRANSPORT *gkt;
} GOST_CLIENT_KEY_EXCHANGE_PARAMS;

/*   PSKeyTransport ::= SEQUENCE {
       PSEXP OCTET STRING,
       ephemeralPublicKey SubjectPublicKeyInfo
   }
   SubjectPublicKeyInfo ::= SEQUENCE {
       algorithm AlgorithmIdentifier,
       subjectPublicKey BITSTRING
   }
   AlgorithmIdentifier ::= SEQUENCE {
       algorithm OBJECT IDENTIFIER,
       parameters ANY OPTIONAL
   }*/
typedef struct PSKeyTransport_st {
    ASN1_OCTET_STRING *psexp;
    X509_PUBKEY       *ephem_key;
    ASN1_OCTET_STRING *ukm;
} PSKeyTransport_gost;

DECLARE_ASN1_FUNCTIONS(PSKeyTransport_gost)
/*
 * Hacks to shorten symbols to 31 characters or less, or OpenVMS. This mimics
 * what's done in symhacks.h, but since this is a very local header file, I
 * prefered to put this hack directly here. -- Richard Levitte
 */
# ifdef OPENSSL_SYS_VMS
#  undef GOST_CLIENT_KEY_EXCHANGE_PARAMS_it
#  define GOST_CLIENT_KEY_EXCHANGE_PARAMS_it      GOST_CLIENT_KEY_EXC_PARAMS_it
#  undef GOST_CLIENT_KEY_EXCHANGE_PARAMS_new
#  define GOST_CLIENT_KEY_EXCHANGE_PARAMS_new     GOST_CLIENT_KEY_EXC_PARAMS_new
#  undef GOST_CLIENT_KEY_EXCHANGE_PARAMS_free
#  define GOST_CLIENT_KEY_EXCHANGE_PARAMS_free    GOST_CLIENT_KEY_EXC_PARAMS_free
#  undef d2i_GOST_CLIENT_KEY_EXCHANGE_PARAMS
#  define d2i_GOST_CLIENT_KEY_EXCHANGE_PARAMS     d2i_GOST_CLIENT_KEY_EXC_PARAMS
#  undef i2d_GOST_CLIENT_KEY_EXCHANGE_PARAMS
#  define i2d_GOST_CLIENT_KEY_EXCHANGE_PARAMS     i2d_GOST_CLIENT_KEY_EXC_PARAMS
# endif                         /* End of hack */
DECLARE_ASN1_FUNCTIONS(GOST_CLIENT_KEY_EXCHANGE_PARAMS)
typedef struct {
    ASN1_OBJECT *key_params;
    ASN1_OBJECT *hash_params;
    ASN1_OBJECT *cipher_params;
} GOST_KEY_PARAMS;

DECLARE_ASN1_FUNCTIONS(GOST_KEY_PARAMS)

typedef struct {
    ASN1_OCTET_STRING *iv;
    ASN1_OBJECT *enc_param_set;
} GOST_CIPHER_PARAMS;

DECLARE_ASN1_FUNCTIONS(GOST_CIPHER_PARAMS)

typedef struct {
	ASN1_OCTET_STRING *ukm;
	} GOST2015_CIPHER_PARAMS;

DECLARE_ASN1_FUNCTIONS(GOST2015_CIPHER_PARAMS)

typedef struct {
    ASN1_OCTET_STRING *masked_priv_key;
    ASN1_OCTET_STRING *public_key;
} MASKED_GOST_KEY;

DECLARE_ASN1_FUNCTIONS(MASKED_GOST_KEY)

/*============== Message digest  and cipher related structures  ==========*/
    /*
     * Structure used as EVP_MD_CTX-md_data. It allows to avoid storing
     * in the md-data pointers to dynamically allocated memory. I
     * cannot invent better way to avoid memory leaks, because openssl
     * insist on invoking Init on Final-ed digests, and there is no
     * reliable way to find out whether pointer in the passed md_data is
     * valid or not.
     */
struct ossl_gost_digest_ctx {
    gost_hash_ctx dctx;
    gost_ctx cctx;
};
/* Cipher context used for EVP_CIPHER operation */
struct ossl_gost_cipher_ctx {
    int paramNID;
    unsigned int count;
    int key_meshing;
    unsigned char kdf_seed[8];
    unsigned char tag[8];
    gost_ctx cctx;
    EVP_MD_CTX *omac_ctx;
};
/* Structure to map parameter NID to S-block */
struct gost_cipher_info {
    int nid;
    gost_subst_block *sblock;
    int key_meshing;
};
/* Context for MAC */
struct ossl_gost_imit_ctx {
    gost_ctx cctx;
    unsigned char buffer[8];
    unsigned char partial_block[8];
    unsigned int count;
    int key_meshing;
    int bytes_left;
    int key_set;
    int dgst_size;
};
/* Find encryption params from ASN1_OBJECT */
const struct gost_cipher_info *get_encryption_params(ASN1_OBJECT *obj);

void inc_counter(unsigned char *counter, size_t counter_bytes);

# define EVP_MD_CTRL_KEY_LEN (EVP_MD_CTRL_ALG_CTRL+3)
# define EVP_MD_CTRL_SET_KEY (EVP_MD_CTRL_ALG_CTRL+4)
/* EVP_PKEY_METHOD key encryption callbacks */
/* From gost_ec_keyx.c */
int pkey_gost_encrypt(EVP_PKEY_CTX *pctx, unsigned char *out,
                           size_t *out_len, const unsigned char *key,
                           size_t key_len);

int pkey_gost_decrypt(EVP_PKEY_CTX *pctx, unsigned char *key,
                           size_t *key_len, const unsigned char *in,
                           size_t in_len);
/* derive functions */
/* From gost_ec_keyx.c */
int pkey_gost_ec_derive(EVP_PKEY_CTX *ctx, unsigned char *key, size_t *keylen);
int fill_GOST_EC_params(EC_KEY *eckey, int nid);
int gost_ec_keygen(EC_KEY *ec);

ECDSA_SIG *gost_ec_sign(const unsigned char *dgst, int dlen, EC_KEY *eckey);
int gost_ec_verify(const unsigned char *dgst, int dgst_len,
                   ECDSA_SIG *sig, EC_KEY *ec);
int gost_ec_compute_public(EC_KEY *ec);
int gost_ec_point_mul(const EC_GROUP *group, EC_POINT *r, const BIGNUM *n,
                      const EC_POINT *q, const BIGNUM *m, BN_CTX *ctx);

#define CURVEDEF(a) \
int point_mul_##a(const EC_GROUP *group, EC_POINT *r, const EC_POINT *q, const BIGNUM *m, BN_CTX *ctx);\
int point_mul_g_##a(const EC_GROUP *group, EC_POINT *r, const BIGNUM *n, BN_CTX *ctx);\
int point_mul_two_##a(const EC_GROUP *group, EC_POINT *r, const BIGNUM *n, const EC_POINT *q, const BIGNUM *m, BN_CTX *ctx);

CURVEDEF(id_GostR3410_2001_CryptoPro_A_ParamSet)
CURVEDEF(id_GostR3410_2001_CryptoPro_B_ParamSet)
CURVEDEF(id_GostR3410_2001_CryptoPro_C_ParamSet)
CURVEDEF(id_GostR3410_2001_TestParamSet)
CURVEDEF(id_tc26_gost_3410_2012_256_paramSetA)
CURVEDEF(id_tc26_gost_3410_2012_512_paramSetA)
CURVEDEF(id_tc26_gost_3410_2012_512_paramSetB)
CURVEDEF(id_tc26_gost_3410_2012_512_paramSetC)

/* VKO */
int VKO_compute_key(unsigned char *shared_key,
                    const EC_POINT *pub_key, const EC_KEY *priv_key,
                    const unsigned char *ukm, const size_t ukm_size,
                    const int vko_dgst_nid);

/* KDF TREE */
int gost_kdftree2012_256(unsigned char *keyout, size_t keyout_len,
                         const unsigned char *key, size_t keylen,
                         const unsigned char *label, size_t label_len,
                         const unsigned char *seed, size_t seed_len,
                         const size_t representation);

int gost_tlstree(int cipher_nid, const unsigned char *in, unsigned char *out,
                 const unsigned char *tlsseq);
/* KExp/KImp */
int gost_kexp15(const unsigned char *shared_key, const int shared_len,
                int cipher_nid, const unsigned char *cipher_key,
                int mac_nid, unsigned char *mac_key,
                const unsigned char *iv, const size_t ivlen,
                unsigned char *out, int *out_len);
int gost_kimp15(const unsigned char *expkey, const size_t expkeylen,
                int cipher_nid, const unsigned char *cipher_key,
                int mac_nid, unsigned char *mac_key,
                const unsigned char *iv, const size_t ivlen,
                unsigned char *shared_key);
/*============== miscellaneous functions============================= */
/*
 * Store bignum in byte array of given length, prepending by zeros if
 * nesseccary
 */
int store_bignum(const BIGNUM *bn, unsigned char *buf, int len);
/* Pack GOST R 34.10 signature according to CryptoPro rules */
int pack_sign_cp(ECDSA_SIG *s, int order, unsigned char *sig, size_t *siglen);
/* from ameth.c */
/* Get private key as BIGNUM from both 34.10-2001 keys*/
/* Returns pointer into EVP_PKEY structure */
BIGNUM *gost_get0_priv_key(const EVP_PKEY *pkey);
/* from gost_crypt.c */
/* Decrements 8-byte sequence */ 
int decrement_sequence(unsigned char *seq, int decrement);

/* Struct describing cipher and used for init/deinit.*/
struct gost_cipher_st {
    struct gost_cipher_st *template; /* template struct */
    int nid;
    EVP_CIPHER *cipher;
    int block_size;     /* (bytes) */
    int key_len;        /* (bytes) */
    int iv_len;
    int flags;
    int (*init) (EVP_CIPHER_CTX *ctx, const unsigned char *key,
                 const unsigned char *iv, int enc);
    int (*do_cipher)(EVP_CIPHER_CTX *ctx, unsigned char *out,
                     const unsigned char *in, size_t inl);
    int (*cleanup)(EVP_CIPHER_CTX *);
    int ctx_size;
    int (*set_asn1_parameters)(EVP_CIPHER_CTX *, ASN1_TYPE *);
    int (*get_asn1_parameters)(EVP_CIPHER_CTX *, ASN1_TYPE *);
    int (*ctrl)(EVP_CIPHER_CTX *, int type, int arg, void *ptr);
};
typedef struct gost_cipher_st GOST_cipher;

EVP_CIPHER *GOST_init_cipher(GOST_cipher *c);
void GOST_deinit_cipher(GOST_cipher *c);

/* ENGINE implementation data */
extern GOST_cipher Gost28147_89_cipher;
extern GOST_cipher Gost28147_89_cbc_cipher;
extern GOST_cipher Gost28147_89_cnt_cipher;
extern GOST_cipher Gost28147_89_cnt_12_cipher;
extern GOST_cipher magma_ctr_cipher;
extern GOST_cipher magma_ctr_acpkm_cipher;
extern GOST_cipher magma_ctr_acpkm_omac_cipher;
extern GOST_cipher magma_ecb_cipher;
extern GOST_cipher magma_cbc_cipher;
extern GOST_cipher magma_mgm_cipher;
extern GOST_cipher grasshopper_ecb_cipher;
extern GOST_cipher grasshopper_cbc_cipher;
extern GOST_cipher grasshopper_cfb_cipher;
extern GOST_cipher grasshopper_ofb_cipher;
extern GOST_cipher grasshopper_ctr_cipher;
extern GOST_cipher grasshopper_mgm_cipher;
extern GOST_cipher grasshopper_ctr_acpkm_cipher;
extern GOST_cipher grasshopper_ctr_acpkm_omac_cipher;
extern GOST_cipher magma_kexp15_cipher;
extern GOST_cipher kuznyechik_kexp15_cipher;

/* Provider implementation data */
extern const OSSL_ALGORITHM GOST_prov_ciphers[];
void GOST_prov_deinit_ciphers(void);

struct gost_digest_st {
    struct gost_digest_st *template;
    int nid;
    const char *alias;
    EVP_MD *digest;
    int result_size;
    int input_blocksize;
    int app_datasize;
    int flags;
    int (*init)(EVP_MD_CTX *ctx);
    int (*update)(EVP_MD_CTX *ctx, const void *data, size_t count);
    int (*final)(EVP_MD_CTX *ctx, unsigned char *md);
    int (*copy)(EVP_MD_CTX *to, const EVP_MD_CTX *from);
    int (*cleanup)(EVP_MD_CTX *ctx);
    int (*ctrl)(EVP_MD_CTX *ctx, int cmd, int p1, void *p2);
};
typedef struct gost_digest_st GOST_digest;

EVP_MD *GOST_init_digest(GOST_digest *d);
void GOST_deinit_digest(GOST_digest *d);

/* ENGINE implementation data */
extern GOST_digest GostR3411_94_digest;
extern GOST_digest Gost28147_89_MAC_digest;
extern GOST_digest Gost28147_89_mac_12_digest;
extern GOST_digest GostR3411_2012_256_digest;
extern GOST_digest GostR3411_2012_512_digest;
extern GOST_digest magma_mac_digest;
extern GOST_digest grasshopper_mac_digest;
extern GOST_digest kuznyechik_ctracpkm_omac_digest;

/* Provider implementation data */
extern const OSSL_ALGORITHM GOST_prov_digests[];
void GOST_prov_deinit_digests(void);

/* job to initialize a missing NID */
struct gost_nid_job {
    const char *sn;
    const char *ln;
    void (*callback)(int nid);
    ASN1_OBJECT *asn1;
};

typedef struct gost_nid_job GOST_NID_JOB;

extern GOST_NID_JOB magma_mgm_NID;
extern GOST_NID_JOB kuznyechik_mgm_NID;

#endif
/* vim: set expandtab cinoptions=\:0,l1,t0,g0,(0 sw=4 : */
