/*
 * Simple Client/Server connection test
 *
 * Based on OpenSSL example code.
 * Copyright (C) 2019 vt@altlinux.org. All Rights Reserved.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
#include "e_gost_err.h"
#include "gost_lcl.h"
#include <openssl/evp.h>
#include <openssl/ssl.h>
#include <openssl/bio.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#include <openssl/obj_mac.h>
#include <openssl/x509v3.h>
#include <openssl/ec.h>
#include <openssl/bn.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>

#ifdef __GNUC__
/* For X509_NAME_add_entry_by_txt */
# pragma GCC diagnostic ignored "-Wpointer-sign"
#endif

#define T(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        OpenSSLDie(__FILE__, __LINE__, #e); \
    }
#define TE(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        fprintf(stderr, "Error at %s:%d %s\n", __FILE__, __LINE__, #e); \
        return -1; \
    }

#define cRED	"\033[1;31m"
#define cDRED	"\033[0;31m"
#define cGREEN	"\033[1;32m"
#define cDGREEN	"\033[0;32m"
#define cBLUE	"\033[1;34m"
#define cDBLUE	"\033[0;34m"
#define cNORM	"\033[m"
#define TEST_ASSERT(e) {if ((test = (e))) \
		 printf(cRED "  Test FAILED\n" cNORM); \
	     else \
		 printf(cGREEN "  Test passed\n" cNORM);}

struct certkey {
    EVP_PKEY *pkey;
    X509 *cert;
};

static int verbose;
static const char *cipher_list;

static void err(int eval, const char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    printf(": %s\n", strerror(errno));
    exit(eval);
}

/* Generate simple cert+key pair. Based on req.c */
static struct certkey certgen(const char *algname, const char *paramset)
{
    /* Keygen. */
    EVP_PKEY *tkey;
    T(tkey = EVP_PKEY_new());
    T(EVP_PKEY_set_type_str(tkey, algname, strlen(algname)));
    EVP_PKEY_CTX *ctx;
    T(ctx = EVP_PKEY_CTX_new(tkey, NULL));
    T(EVP_PKEY_keygen_init(ctx));
    if (paramset)
	T(EVP_PKEY_CTX_ctrl_str(ctx, "paramset", paramset));
    EVP_PKEY *pkey = NULL;
    T((EVP_PKEY_keygen(ctx, &pkey)) == 1);
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(tkey);

    /* REQ. */
    X509_REQ *req = NULL;
    T(req = X509_REQ_new());
    T(X509_REQ_set_version(req, 0L));
    X509_NAME *name;
    T(name = X509_NAME_new());
    T(X509_NAME_add_entry_by_txt(name, "O", MBSTRING_ASC, (unsigned char *)"Test CA", -1, -1, 0));
    T(X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, (unsigned char *)"Test Key", -1, -1, 0));
    T(X509_REQ_set_subject_name(req, name));
    T(X509_REQ_set_pubkey(req, pkey));
    X509_NAME_free(name);

    /* Cert. */
    X509 *x509ss = NULL;
    T(x509ss = X509_new());
    T(X509_set_version(x509ss, 2));
    BIGNUM *brnd = BN_new();
    T(BN_rand(brnd, 20 * 8 - 1, -1, 0));
    T(BN_to_ASN1_INTEGER(brnd, X509_get_serialNumber(x509ss)));
    T(X509_set_issuer_name(x509ss, X509_REQ_get_subject_name(req)));
    T(X509_gmtime_adj(X509_getm_notBefore(x509ss), 0));
    T(X509_time_adj_ex(X509_getm_notAfter(x509ss), 1, 0, NULL));
    T(X509_set_subject_name(x509ss, X509_REQ_get_subject_name(req)));
    T(X509_set_pubkey(x509ss, X509_REQ_get0_pubkey(req)));
    X509_REQ_free(req);
    BN_free(brnd);

    X509V3_CTX v3ctx;
    X509V3_set_ctx_nodb(&v3ctx);
    X509V3_set_ctx(&v3ctx, x509ss, x509ss, NULL, NULL, 0);
    X509_EXTENSION *ext;
    T(ext = X509V3_EXT_conf_nid(NULL, &v3ctx, NID_basic_constraints, "critical,CA:TRUE"));
    T(X509_add_ext(x509ss, ext, 0));
    X509_EXTENSION_free(ext);
    T(ext = X509V3_EXT_conf_nid(NULL, &v3ctx, NID_subject_key_identifier, "hash"));
    T(X509_add_ext(x509ss, ext, 1));
    X509_EXTENSION_free(ext);
    T(ext = X509V3_EXT_conf_nid(NULL, &v3ctx, NID_authority_key_identifier, "keyid:always,issuer"));
    T(X509_add_ext(x509ss, ext, 2));
    X509_EXTENSION_free(ext);

    EVP_MD_CTX *mctx;
    T(mctx = EVP_MD_CTX_new());
    T(EVP_DigestSignInit(mctx, NULL, NULL, NULL, pkey));
    T(X509_sign_ctx(x509ss, mctx));
    EVP_MD_CTX_free(mctx);
#if 0
    /* Print cert in text format. */
    X509_print_fp(stdout, x509ss);
#endif
#if 0
    /* Print cert in PEM format. */
    BIO *out = BIO_new_fp(stdout, BIO_NOCLOSE | BIO_FP_TEXT);
    PEM_write_bio_X509(out, x509ss);
    BIO_free_all(out);
#endif
    return (struct certkey){ .pkey = pkey, .cert = x509ss };
}

/* Non-blocking BIO test mechanic is based on sslapitest.c */
int test(const char *algname, const char *paramset)
{
    int ret = 0;

    printf(cBLUE "Test %s", algname);
    if (paramset)
	printf(cBLUE ":%s", paramset);
    printf(cNORM "\n");

    struct certkey ck;
    ck = certgen(algname, paramset);

    SSL_CTX *cctx, *sctx;

    T(sctx = SSL_CTX_new(TLS_server_method()));
    T(SSL_CTX_use_certificate(sctx, ck.cert));
    T(SSL_CTX_use_PrivateKey(sctx, ck.pkey));
    T(SSL_CTX_check_private_key(sctx));

    T(cctx = SSL_CTX_new(TLS_client_method()));

    /* create_ssl_objects */
    SSL *serverssl, *clientssl;
    T(serverssl = SSL_new(sctx));
    T(clientssl = SSL_new(cctx));
    BIO *s_to_c_bio, *c_to_s_bio;
    T(s_to_c_bio = BIO_new(BIO_s_mem()));
    T(c_to_s_bio = BIO_new(BIO_s_mem()));
    /* Non-blocking IO. */
    BIO_set_mem_eof_return(s_to_c_bio, -1);
    BIO_set_mem_eof_return(c_to_s_bio, -1);
    /* Transfer BIOs to SSL objects. */
    SSL_set_bio(serverssl, c_to_s_bio, s_to_c_bio);
    BIO_up_ref(s_to_c_bio);
    BIO_up_ref(c_to_s_bio);
    SSL_set_bio(clientssl, s_to_c_bio, c_to_s_bio);
    c_to_s_bio = NULL;
    c_to_s_bio = NULL;

    /* create_ssl_connection */
    int retc = -1, rets = -1, err;
    do {
        err = SSL_ERROR_WANT_WRITE;
        while (retc <= 0 && err == SSL_ERROR_WANT_WRITE) {
            retc = SSL_connect(clientssl);
            if (retc <= 0)
                err = SSL_get_error(clientssl, retc);
            if (verbose)
                printf("SSL_connect: %d %d\n", retc, err);
        }
        if (retc <= 0 && err != SSL_ERROR_WANT_READ) {
            ERR_print_errors_fp(stderr);
            OpenSSLDie(__FILE__, __LINE__, "SSL_connect");
        }
        err = SSL_ERROR_WANT_WRITE;
        while (rets <= 0 && err == SSL_ERROR_WANT_WRITE) {
            rets = SSL_accept(serverssl);
            if (rets <= 0)
                err = SSL_get_error(serverssl, rets);
            if (verbose)
                printf("SSL_accept: %d %d\n", rets, err);
        }
        if (rets <= 0 && err != SSL_ERROR_WANT_READ &&
            err != SSL_ERROR_WANT_X509_LOOKUP) {
            ERR_print_errors_fp(stderr);
            OpenSSLDie(__FILE__, __LINE__, "SSL_accept");
        }
    } while (retc <=0 || rets <= 0);

    /* Two SSL_read_ex should fail. */
    unsigned char buf;
    size_t readbytes;
    T(!SSL_read_ex(clientssl, &buf, sizeof(buf), &readbytes));
    T(!SSL_read_ex(clientssl, &buf, sizeof(buf), &readbytes));

    /* Connect client to the server. */
    T(SSL_do_handshake(clientssl) == 1);
    printf("Protocol: %s\n", SSL_get_version(clientssl));
    printf("Cipher:   %s\n", SSL_get_cipher_name(clientssl));
    if (verbose) {
        SSL_SESSION *sess = SSL_get0_session(clientssl);
        SSL_SESSION_print_fp(stdout, sess);
    }

    /* Transfer some data. */
    int i;
    for (i = 0; i < 16; i++) {
        char pbuf[512], lbuf[512];

        memset(pbuf, 'c' + i, sizeof(pbuf));
        T(SSL_write(serverssl, pbuf, sizeof(pbuf)) == sizeof(pbuf));
        T(SSL_read(clientssl, lbuf, sizeof(lbuf)) == sizeof(lbuf));
        T(memcmp(pbuf, lbuf, sizeof(pbuf)) == 0);

        memset(lbuf, 's' + i, sizeof(lbuf));
        T(SSL_write(clientssl, lbuf, sizeof(lbuf)) == sizeof(lbuf));
        T(SSL_read(serverssl, pbuf, sizeof(pbuf)) == sizeof(pbuf));
        T(memcmp(pbuf, lbuf, sizeof(pbuf)) == 0);
    }

    SSL_shutdown(clientssl);
    SSL_shutdown(serverssl);

    SSL_free(serverssl);
    SSL_free(clientssl);
    SSL_CTX_free(sctx);
    SSL_CTX_free(cctx);

    /* Every responsible process should free this. */
    X509_free(ck.cert);
    EVP_PKEY_free(ck.pkey);
    return ret;
}

int main(int argc, char **argv)
{
    int ret = 0;

    OPENSSL_add_all_algorithms_conf();

    char *p;
    if ((p = getenv("VERBOSE")))
	verbose = atoi(p);

    ret |= test("rsa", NULL);
    cipher_list = "LEGACY-GOST2012-GOST8912-GOST8912";
    ret |= test("gost2012_256", "A");
    ret |= test("gost2012_256", "B");
    ret |= test("gost2012_256", "C");
    ret |= test("gost2012_256", "TCA");
    ret |= test("gost2012_512", "A");
    ret |= test("gost2012_512", "B");
    ret |= test("gost2012_512", "C");

    if (ret)
	printf(cDRED "= Some tests FAILED!\n" cNORM);
    else
	printf(cDGREEN "= All tests passed!\n" cNORM);
    return ret;
}
