/*
 * Copyright (c) 2019-2020 Dmitry Belyavskiy <beldmit@gmail.com>
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */
#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
# include <Winsock2.h>
# include <stdlib.h>
#else
# include <arpa/inet.h>
#endif
#include <string.h>
#include <stdio.h>
#include <string.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/obj_mac.h>
#include "gost_lcl.h"
#include "e_gost_err.h"
#include "gost_grasshopper_cipher.h"

#define T(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        OpenSSLDie(__FILE__, __LINE__, #e); \
    }

static void hexdump(FILE *f, const char *title, const unsigned char *s, int l)
{
    int n = 0;

    fprintf(f, "%s", title);
    for (; n < l; ++n) {
        if ((n % 16) == 0)
            fprintf(f, "\n%04x", n);
        fprintf(f, " %02x", s[n]);
    }
    fprintf(f, "\n");
}

int main(void)
{
    const unsigned char shared_key[] = {
        0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF
    };

    const unsigned char magma_key[] = {
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
        0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
        0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
    };

    unsigned char mac_magma_key[] = {
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    };

    const unsigned char magma_iv[] = { 0x67, 0xBE, 0xD6, 0x54 };

    const unsigned char magma_export[] = {
        0xCF, 0xD5, 0xA1, 0x2D, 0x5B, 0x81, 0xB6, 0xE1,
        0xE9, 0x9C, 0x91, 0x6D, 0x07, 0x90, 0x0C, 0x6A,
        0xC1, 0x27, 0x03, 0xFB, 0x3A, 0xBD, 0xED, 0x55,
        0x56, 0x7B, 0xF3, 0x74, 0x2C, 0x89, 0x9C, 0x75,
        0x5D, 0xAF, 0xE7, 0xB4, 0x2E, 0x3A, 0x8B, 0xD9
    };

    unsigned char kdftree_key[] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    };

    unsigned char kdf_label[] = { 0x26, 0xBD, 0xB8, 0x78 };
    unsigned char kdf_seed[] =
        { 0xAF, 0x21, 0x43, 0x41, 0x45, 0x65, 0x63, 0x78 };
    const unsigned char kdf_etalon[] = {
        0x22, 0xB6, 0x83, 0x78, 0x45, 0xC6, 0xBE, 0xF6,
        0x5E, 0xA7, 0x16, 0x72, 0xB2, 0x65, 0x83, 0x10,
        0x86, 0xD3, 0xC7, 0x6A, 0xEB, 0xE6, 0xDA, 0xE9,
        0x1C, 0xAD, 0x51, 0xD8, 0x3F, 0x79, 0xD1, 0x6B,
        0x07, 0x4C, 0x93, 0x30, 0x59, 0x9D, 0x7F, 0x8D,
        0x71, 0x2F, 0xCA, 0x54, 0x39, 0x2F, 0x4D, 0xDD,
        0xE9, 0x37, 0x51, 0x20, 0x6B, 0x35, 0x84, 0xC8,
        0xF4, 0x3F, 0x9E, 0x6D, 0xC5, 0x15, 0x31, 0xF9
    };

    const unsigned char tlstree_gh_etalon[] = {
        0x50, 0x76, 0x42, 0xd9, 0x58, 0xc5, 0x20, 0xc6,
        0xd7, 0xee, 0xf5, 0xca, 0x8a, 0x53, 0x16, 0xd4,
        0xf3, 0x4b, 0x85, 0x5d, 0x2d, 0xd4, 0xbc, 0xbf,
        0x4e, 0x5b, 0xf0, 0xff, 0x64, 0x1a, 0x19, 0xff,
    };

    unsigned char buf[32 + 16];
    int ret = 0, err = 0;
    int outlen = 40;
    unsigned char kdf_result[64];

    unsigned char kroot[32];
    unsigned char tlsseq[8];
    unsigned char out[32];

#ifdef _MSC_VER
    _putenv_s("OPENSSL_ENGINES", ENGINE_DIR);
#else
    setenv("OPENSSL_ENGINES", ENGINE_DIR, 0);
#endif
    OPENSSL_add_all_algorithms_conf();
    ERR_load_crypto_strings();
    ENGINE *eng;
    T(eng = ENGINE_by_id("gost"));
    T(ENGINE_init(eng));
    T(ENGINE_set_default(eng, ENGINE_METHOD_ALL));

    memset(buf, 0, sizeof(buf));

    memset(kroot, 0xFF, 32);
    memset(tlsseq, 0, 8);
    tlsseq[7] = 63;
    memset(out, 0, 32);

    ret = gost_kexp15(shared_key, 32,
                      NID_magma_ctr, magma_key,
                      NID_magma_mac, mac_magma_key, magma_iv, 4, buf, &outlen);

    if (ret <= 0) {
        ERR_print_errors_fp(stderr);
        err = 1;
    } else {
        hexdump(stdout, "Magma key export", buf, 40);
        if (memcmp(buf, magma_export, 40) != 0) {
            fprintf(stdout, "ERROR! test failed\n");
            err = 2;
        }
    }

    ret = gost_kimp15(magma_export, 40,
                      NID_magma_ctr, magma_key,
                      NID_magma_mac, mac_magma_key, magma_iv, 4, buf);

    if (ret <= 0) {
        ERR_print_errors_fp(stderr);
        err = 3;
    } else {
        hexdump(stdout, "Magma key import", buf, 32);
        if (memcmp(buf, shared_key, 32) != 0) {
            fprintf(stdout, "ERROR! test failed\n");
            err = 4;
        }
    }

    ret = gost_kdftree2012_256(kdf_result, 64, kdftree_key, 32, kdf_label, 4,
                               kdf_seed, 8, 1);
    if (ret <= 0) {
        ERR_print_errors_fp(stderr);
        err = 5;
    } else {
        hexdump(stdout, "KDF TREE", kdf_result, 64);
        if (memcmp(kdf_result, kdf_etalon, 64) != 0) {
            fprintf(stdout, "ERROR! test failed\n");
            err = 6;
        }
    }

    ret = gost_tlstree(NID_grasshopper_cbc, kroot, out, tlsseq);
    if (ret <= 0) {
        ERR_print_errors_fp(stderr);
        err = 7;
    } else {
        hexdump(stdout, "Gost TLSTREE - grasshopper", out, 32);
        if (memcmp(out, tlstree_gh_etalon, 32) != 0) {
            fprintf(stdout, "ERROR! test failed\n");
            err = 8;
        }
    }

    ENGINE_finish(eng);
    ENGINE_free(eng);

    return err;
}
