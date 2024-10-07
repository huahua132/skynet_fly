/**********************************************************************
 *                        gost89.c                                    *
 *             Copyright (c) 2005-2006 Cryptocom LTD                  *
 *         This file is distributed under the same license as OpenSSL *
 *                                                                    *
 *          Implementation of GOST 28147-89 encryption algorithm      *
 *            No OpenSSL libraries required to compile and use        *
 *                              this code                             *
 **********************************************************************/
#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
#include <string.h>
#include "gost89.h"
#include <stdio.h>
#include <string.h>

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
    int ret = 0;

    const unsigned char initial_key[] = {
        0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF
    };

    const unsigned char meshed_key[] = {
        0x86, 0x3E, 0xA0, 0x17, 0x84, 0x2C, 0x3D, 0x37,
        0x2B, 0x18, 0xA8, 0x5A, 0x28, 0xE2, 0x31, 0x7D,
        0x74, 0xBE, 0xFC, 0x10, 0x77, 0x20, 0xDE, 0x0C,
        0x9E, 0x8A, 0xB9, 0x74, 0xAB, 0xD0, 0x0C, 0xA0,
    };

    unsigned char buf[32];

    gost_ctx ctx;
    kboxinit(&ctx, &Gost28147_TC26ParamSetZ);
    magma_key(&ctx, initial_key);
    magma_get_key(&ctx, buf);

    hexdump(stdout, "Initial key", buf, 32);

    acpkm_magma_key_meshing(&ctx);
    magma_get_key(&ctx, buf);
    hexdump(stdout, "Meshed key - K2", buf, 32);

    if (memcmp(meshed_key, buf, 32)) {
        fprintf(stderr, "Magma meshing failed");
        ret = 1;
    }

    acpkm_magma_key_meshing(&ctx);
    magma_get_key(&ctx, buf);
    hexdump(stdout, "Meshed key - K3", buf, 32);

    acpkm_magma_key_meshing(&ctx);
    magma_get_key(&ctx, buf);
    hexdump(stdout, "Meshed key - K4", buf, 32);

    return ret;
}
