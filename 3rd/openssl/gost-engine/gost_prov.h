/**********************************************************************
 *                 gost_prov.h - The provider itself                  *
 *                                                                    *
 *      Copyright (c) 2021 Richard Levitte <richard@levitte.org>      *
 *     This file is distributed under the same license as OpenSSL     *
 *                                                                    *
 *                Requires OpenSSL 3.0 for compilation                *
 **********************************************************************/

#include <openssl/core.h>
#include <openssl/engine.h>

struct provider_ctx_st {
    OSSL_LIB_CTX *libctx;
    const OSSL_CORE_HANDLE *core_handle;
    struct proverr_functions_st *proverr_handle;

    /*
     * "internal" GOST engine, which is the implementation that all the
     * provider functions will use to access the crypto functionality.
     * This is pure hackery, but allows us to quickly wrap all the ENGINE
     * function with provider wrappers.  There is no other supported way
     * to do this.
     */
    ENGINE *e;
};
typedef struct provider_ctx_st PROV_CTX;
