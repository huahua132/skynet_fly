/**********************************************************************
 *             Simple benchmarking for gost-engine                    *
 *                                                                    *
 *             Copyright (c) 2018 Cryptocom LTD                       *
 *             Copyright (c) 2018 <vt@altlinux.org>.                  *
 *       This file is distributed under the same license as OpenSSL   *
 **********************************************************************/

#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <getopt.h>
#include <openssl/rand.h>
#include <openssl/conf.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/engine.h>

const char *tests[] = {
    "md_gost12_256", "gost2012_256", "A",
    "md_gost12_256", "gost2012_256", "B",
    "md_gost12_256", "gost2012_256", "C",
    "md_gost12_256", "gost2012_256", "TCA",
    "md_gost12_256", "gost2012_256", "TCB",
    "md_gost12_256", "gost2012_256", "TCC",
    "md_gost12_256", "gost2012_256", "TCD",

    "md_gost12_512", "gost2012_512", "A",
    "md_gost12_512", "gost2012_512", "B",
    "md_gost12_512", "gost2012_512", "C",

    NULL,
};

static EVP_PKEY *create_key(const char *algname, const char *param)
{
	EVP_PKEY *key1 = EVP_PKEY_new(), *newkey = NULL;
	EVP_PKEY_CTX *ctx = NULL;

	if (EVP_PKEY_set_type_str(key1, algname, strlen(algname)) <= 0)
		  goto err;

	if (!(ctx = EVP_PKEY_CTX_new(key1, NULL)))
		  goto err;

	if (EVP_PKEY_keygen_init(ctx) == 0)
		  goto err;

	if (ERR_peek_last_error())
		  goto err;

	if (EVP_PKEY_CTX_ctrl_str(ctx, "paramset", param) <= 0)
		  goto err;

	if (EVP_PKEY_keygen(ctx, &newkey) <= 0)
		  goto err;

err:
	if(ctx)
		EVP_PKEY_CTX_free(ctx);
	EVP_PKEY_free(key1);
	return newkey;
}

void usage(char *name)
{
	fprintf(stderr, "usage: %s [-l data_len] [-c cycles]\n", name);
	exit(1);
}

int main(int argc, char **argv)
{
	unsigned int data_len = 1;
	unsigned int cycles = 100;
	int option;
	clockid_t clock_type = CLOCK_MONOTONIC;
	int test, test_count = 0;

	opterr = 0;
	while((option = getopt(argc, argv, "l:c:C")) >= 0)
	{
		switch (option)
		{
			case 'l':
				data_len = atoi(optarg);
				break;
			case 'c':
				cycles = atoi(optarg);
				break;
			case 'C':
				clock_type = CLOCK_PROCESS_CPUTIME_ID;
				break;
			default:
				usage(argv[0]);
				break;
		}
	}
	if (optind < argc) usage(argv[0]);
	if (cycles < 100) { printf("cycles too low\n"); exit(1); }

	OPENSSL_add_all_algorithms_conf();
	ERR_load_crypto_strings();

	for (test = 0; tests[test]; test += 3) {
	    double diff[2]; /* sign, verify */
	    const char *digest = tests[test];
	    const char *algo   = tests[test + 1];
	    const char *param  = tests[test + 2];
	    const EVP_MD *mdtype;
	    EVP_MD_CTX *md_ctx;
	    unsigned int siglen;
	    unsigned char *sigbuf;
	    EVP_PKEY *pkey;
	    unsigned char *data;
	    int pass;

	    md_ctx = EVP_MD_CTX_new();
	    mdtype = EVP_get_digestbyname(digest);
	    if (!mdtype)
		continue;
	    pkey = create_key(algo, param);
	    data = (unsigned char *) malloc(data_len);
	    if (!pkey)
		continue;

	    test_count++;
	    printf("wait...");
	    fflush(stdout);
	    siglen = EVP_PKEY_size(pkey);
	    sigbuf = malloc(siglen * cycles);
	if (!sigbuf) {
	    fprintf(stderr, "No tests were run, malloc failure.\n");
	    exit(1);
	}

	    for (pass = 0; pass < 2; pass++) {
		struct timespec ts;
		struct timeval debut, fin, delta;
		int err;
		unsigned int i;

		clock_gettime(clock_type, &ts);
		TIMESPEC_TO_TIMEVAL(&debut, &ts);

		if (pass == 0) { /* sign */
		    for (i = 0; i < cycles; i++) {
			EVP_SignInit(md_ctx, mdtype);
			err = EVP_SignUpdate(md_ctx, data, data_len)
			   && EVP_SignFinal(md_ctx, &sigbuf[siglen * i],
			    (unsigned int *)&siglen, pkey);
			if (err != 1)
			    printf("!");
			EVP_MD_CTX_reset(md_ctx);
		    }
		} else { /* verify */
		    for (i = 0; i < cycles; i++) {
			EVP_VerifyInit(md_ctx, mdtype);
			err = EVP_VerifyUpdate(md_ctx, data, data_len)
			   && EVP_VerifyFinal(md_ctx, &sigbuf[siglen * i],
			    siglen, pkey);
			EVP_MD_CTX_reset(md_ctx);
			if (err != 1)
			    printf("!");
		    }
		}

		clock_gettime(clock_type, &ts);
		TIMESPEC_TO_TIMEVAL(&fin, &ts);
		timersub(&fin, &debut, &delta);
		diff[pass] = (double)delta.tv_sec + (double)delta.tv_usec / 1000000;
	    }
	    printf("\r%s %s: sign: %.1f/s, verify: %.1f/s\n", algo, param,
		(double)cycles / diff[0], (double)cycles / diff[1]);
	    EVP_PKEY_free(pkey);
	    free(sigbuf);
	    free(data);
	}

	if (!test_count) {
	    fprintf(stderr, "No tests were run, something is wrong.\n");
	    exit(1);
	}
	exit(0);
}
