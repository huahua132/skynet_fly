/*
 * Copyright (C) 2018 vt@altlinux.org. All Rights Reserved.
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */

#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
#include "gost_lcl.h"
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#include <openssl/obj_mac.h>
#include <openssl/ec.h>
#include <openssl/bn.h>
#include <string.h>

#define T(e) \
    if (!(e)) { \
        ERR_print_errors_fp(stderr); \
        OpenSSLDie(__FILE__, __LINE__, #e); \
    }

#define cRED	"\033[1;31m"
#define cDRED	"\033[0;31m"
#define cGREEN	"\033[1;32m"
#define cDGREEN	"\033[0;32m"
#define cBLUE	"\033[1;34m"
#define cDBLUE	"\033[0;34m"
#define cNORM	"\033[m"
#define TEST_ASSERT(e) { \
	test = e; \
	if (test) \
		printf(cRED "  Test FAILED" cNORM "\n"); \
	else \
		printf(cGREEN "  Test passed" cNORM "\n"); \
}

struct test_curve {
    int nid;
    const char *name;
    int listed;
};

static struct test_curve test_curves[] = {
#if 2001
    { NID_id_GostR3410_2001_TestParamSet, },
#endif
    { NID_id_GostR3410_2001_CryptoPro_A_ParamSet },
    { NID_id_GostR3410_2001_CryptoPro_B_ParamSet },
    { NID_id_GostR3410_2001_CryptoPro_C_ParamSet },
    { NID_id_GostR3410_2001_CryptoPro_XchA_ParamSet },
    { NID_id_GostR3410_2001_CryptoPro_XchB_ParamSet },
    { NID_id_tc26_gost_3410_2012_512_paramSetA, "id-tc26-gost-3410-2012-512-paramSetA", },
    { NID_id_tc26_gost_3410_2012_512_paramSetB, "id-tc26-gost-3410-2012-512-paramSetB", },
    { NID_id_tc26_gost_3410_2012_512_paramSetC, "id-tc26-gost-3410-2012-512-paramSetC", },
    { NID_id_tc26_gost_3410_2012_256_paramSetA, "id-tc26-gost-3410-2012-256-paramSetA", },
    { NID_id_tc26_gost_3410_2012_256_paramSetB, "id-tc26-gost-3410-2012-256-paramSetB", },
    { NID_id_tc26_gost_3410_2012_256_paramSetC, "id-tc26-gost-3410-2012-256-paramSetC", },
    { NID_id_tc26_gost_3410_2012_256_paramSetD, "id-tc26-gost-3410-2012-256-paramSetD", },
    0,
};

static struct test_curve *get_test_curve(int nid)
{
    int i;

    for (i = 0; test_curves[i].nid; i++)
	if (test_curves[i].nid == nid)
	    return &test_curves[i];
    return NULL;
}

static void print_bn(const char *name, const BIGNUM *n)
{
    printf("%3s = ", name);
    BN_print_fp(stdout, n);
    printf("\n");
}

// https://wiki.openssl.org/index.php/Elliptic_Curve_Cryptography
static int parameter_test(struct test_curve *tc)
{
    const int nid = tc->nid;
    int test;

    printf(cBLUE "Test curve NID %d" cNORM, nid);
    if (tc->name)
	printf(cBLUE ": %s" cNORM, tc->name);
    else if (OBJ_nid2sn(nid))
	printf(cBLUE ": %s" cNORM, OBJ_nid2sn(nid));
    printf("\n");

    if (!OBJ_nid2obj(nid)) {
	printf(cRED "NID %d not found" cNORM "\n", nid);
	return 1;
    }

    /* nid resolves in both directions */
    const char *sn, *ln;
    T(sn = OBJ_nid2sn(nid));
    T(ln = OBJ_nid2ln(nid));
    if (tc->name)
	T(!strcmp(tc->name, OBJ_nid2sn(nid)));
    T(nid == OBJ_sn2nid(sn));
    T(nid == OBJ_ln2nid(ln));

    EC_KEY *ec;
    T(ec = EC_KEY_new());
    if (!fill_GOST_EC_params(ec, nid)) {
	printf(cRED "fill_GOST_EC_params FAIL" cNORM "\n");
	ERR_print_errors_fp(stderr);
	return 1;
    }

    const EC_GROUP *group;
    T(group = EC_KEY_get0_group(ec));

    BN_CTX *ctx;
    T(ctx = BN_CTX_new());
    BIGNUM *p, *a, *b;
    T(p = BN_new());
    T(a = BN_new());
    T(b = BN_new());
    EC_GROUP_get_curve(group, p, a, b, ctx);
    print_bn("p", p);
    print_bn("a", a);
    print_bn("b", b);
    T(!BN_is_zero(p));
    T(BN_is_odd(p)); /* Should be odd for F_p */
    T(!BN_is_zero(a));
    T(!BN_is_zero(b));

    /* Check generator */
    const EC_POINT *generator;
    T(generator = EC_GROUP_get0_generator(group));
    BIGNUM *x, *y;
    T(x = BN_new());
    T(y = BN_new());
    T(EC_POINT_get_affine_coordinates(group, generator, x, y, ctx));
    print_bn("x", x);
    print_bn("y", y);
    T(!BN_is_zero(y));

    /* Generator is not identity element 0 */
    T(EC_POINT_is_at_infinity(group, generator) == 0);

    /* x and y is in range [1 .. p-1] */
    T(!BN_is_negative(x));
    T(!BN_is_negative(y));
    T(BN_cmp(x, p) < 0);
    T(BN_cmp(y, p) < 0);

    /* Generator should be on curve */
    T(EC_POINT_is_on_curve(group, generator, ctx) == 1);

    /* y^2 == (x^3 + ax + b) mod p
     * Should be same as EC_POINT_is_on_curve(generator),
     * but, let's calculate it manually. */
    BIGNUM *yy  = BN_new();
    BIGNUM *r   = BN_new();
    BIGNUM *xxx = BN_new();
    BIGNUM *ax  = BN_new();
    T(yy && r && xxx && ax);
    BN_set_word(r, 2);
    BN_mod_exp(yy, y, r, p, ctx);
    BN_set_word(r, 3);
    BN_mod_exp(xxx, x, r, p, ctx);
    BN_mod_mul(ax, a, x, p, ctx);
    BN_mod_add(xxx, xxx, ax, p, ctx);
    BN_mod_add(xxx, xxx, b, p, ctx);
    T(BN_cmp(yy, xxx) == 0);
    BN_free(yy);
    BN_free(r);
    BN_free(xxx);
    BN_free(ax);
    BN_free(p);
    BN_free(a);
    BN_free(b);
    BN_free(x);
    BN_free(y);

    /* Check order */
    const BIGNUM *order;
    T(order = EC_GROUP_get0_order(group));
    T(!BN_is_zero(order));
    print_bn("q", order);
    T(BN_is_odd(order));
    EC_POINT *point;
    T((point = EC_POINT_new(group)));
    T(EC_POINT_mul(group, point, NULL, generator, order, ctx));
    /* generator * order is the point at infinity? */
    T(EC_POINT_is_at_infinity(group, point) == 1);
    EC_POINT_free(point);

    /* Check if order is cyclic */
    BIGNUM *k1 = BN_new();
    BIGNUM *k2 = BN_new();
    EC_POINT *p1 = EC_POINT_new(group);
    EC_POINT *p2 = EC_POINT_new(group);
    BN_set_word(k1, 3);
    BN_set_word(k2, 3);
    BN_add(k2, k2, order);
    T(EC_POINT_mul(group, p1, NULL, generator, k1, ctx));
    T(EC_POINT_mul(group, p2, NULL, generator, k2, ctx));
    T(EC_POINT_cmp(group, p1, p2, ctx) == 0);
    BN_free(k1);
    BN_free(k2);
    EC_POINT_free(p1);
    EC_POINT_free(p2);

    /* Cofactor is 1 or 4 */
    const BIGNUM *c;
    T(c = EC_GROUP_get0_cofactor(group));
    T(BN_is_word(c, 1) || BN_is_word(c, 4));

    BN_CTX_free(ctx);
    EC_KEY_free(ec);
    TEST_ASSERT(0);
    return test;
}

int main(int argc, char **argv)
{
    int ret = 0;

    struct test_curve *tc;
    for (tc = test_curves; tc->nid; tc++) {
	ret |= parameter_test(tc);
    }

    if (ret)
	printf(cDRED "= Some tests FAILED!" cNORM "\n");
    else
	printf(cDGREEN "= All tests passed!" cNORM "\n");
    return ret;
}
