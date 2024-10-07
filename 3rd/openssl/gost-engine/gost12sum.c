/**********************************************************************
 *                          gost12sum.c                                 *
 *             Copyright (c) 2005-2019 Cryptocom LTD                  *
 *         This file is distributed under same license as OpenSSL     *
 *                                                                    *
 *    Implementation of GOST R 34.11-2012 hash function as            *
 *    command line utility more or less interface                     *
 *    compatible with md5sum and sha1sum                              *
 *    Doesn't need OpenSSL                                            *
 **********************************************************************/
#include <stdio.h>
#include <stdlib.h>
#ifdef _MSC_VER
#include "getopt.h"
# ifndef PATH_MAX
#  define PATH_MAX _MAX_PATH
# endif
#include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#else
#include <unistd.h>
#endif
#include <limits.h>
#include <fcntl.h>
#ifdef _WIN32
# include <io.h>
#endif
#include <string.h>
#include "gosthash2012.h"
#define BUF_SIZE 262144
#define MAX_HASH_TXT_BYTES 128
#define gost_hash_ctx gost2012_hash_ctx

typedef unsigned char byte;
int hash_file(gost_hash_ctx * ctx, char *filename, char *sum, int mode,
              int hashsize);
int hash_stream(gost_hash_ctx * ctx, int fd, char *sum, int hashsize);
int get_line(FILE *f, char *hash, char *filename, int verbose, int *size);

void help()
{
    fprintf(stderr, "Calculates GOST R 34.11-2012 hash function\n\n");
    fprintf(stderr, "gost12sum [-vl] [-c [file]]| [files]|-x\n"
            "\t-c check message digests (default is generate)\n"
            "\t-v verbose, print file names when checking\n"
            "\t-l use 512 bit hash (default 256 bit)\n"
            "\t-x read filenames from stdin rather than from arguments (256 bit only)\n"
            "\t-h print this help\n"
            "The input for -c should be the list of message digests and file names\n"
            "that is printed on stdout by this program when it generates digests.\n");
    exit(3);
}

#ifndef O_BINARY
# define O_BINARY 0
#endif

int start_hash(gost_hash_ctx * ctx, int hashsize)
{
    init_gost2012_hash_ctx(ctx, hashsize);
    return 1;
}

int hash_block(gost_hash_ctx * ctx, const byte * block, size_t length)
{
    gost2012_hash_block(ctx, block, length);
    return 1;
}

int finish_hash(gost_hash_ctx * ctx, byte * hashval)
{
    gost2012_finish_hash(ctx, hashval);
    return 1;
}

int main(int argc, char **argv)
{
    int c, i;
    int verbose = 0;
    int errors = 0;
    int open_mode = O_RDONLY | O_BINARY;
    FILE *check_file = NULL;
    int filenames_from_stdin = 0;
    int hashsize = 32;
    gost_hash_ctx ctx;

    while ((c = getopt(argc, argv, "hxlvc::")) != -1) {
        switch (c) {
        case 'h':
            help();
            exit(0);
            break;
        case 'v':
            verbose = 1;
            break;
        case 'l':
            hashsize = 64;
            break;
        case 'x':
            filenames_from_stdin = 1;
            break;
        case 'c':
            if (optarg) {
                check_file = fopen(optarg, "r");
                if (!check_file) {
                    perror(optarg);
                    exit(2);
                }
            } else {
                check_file = stdin;
            }
            break;
        default:
            fprintf(stderr, "invalid option %c\n", optopt);
            help();
        }
    }

    if (check_file) {
        char inhash[MAX_HASH_TXT_BYTES + 1], calcsum[MAX_HASH_TXT_BYTES + 1],
            filename[PATH_MAX];
        int failcount = 0, count = 0;
        int expected_hash_size = 0;
        if (check_file == stdin && optind < argc) {
            check_file = fopen(argv[optind], "r");
            if (!check_file) {
                perror(argv[optind]);
                exit(2);
            }
        }
        while (get_line
               (check_file, inhash, filename, verbose, &expected_hash_size)) {
            int error = 0;
            if (expected_hash_size == 0) {
                fprintf(stderr, "%s: invalid hash length\n", filename);
                errors++;
                count++;
                continue;
            }

            if (!hash_file
                (&ctx, filename, calcsum, open_mode, expected_hash_size)) {
                errors++;
                error = 1;
            }
            count++;
            if (error)
                continue;

            if (!strncmp(calcsum, inhash, expected_hash_size * 2 + 1)) {
                if (verbose) {
                    fprintf(stderr, "%s\tOK\n", filename);
                }
            } else {
                if (verbose) {
                    fprintf(stderr, "%s\tFAILED\n", filename);
                } else {
                    fprintf(stderr, "%s: GOST hash sum check failed\n",
                            filename);
                }
                failcount++;
            }
        }
        if (errors) {
            fprintf(stderr,
                    "%s: WARNING %d of %d file(s) cannot be processed\n",
                    argv[0], errors, count);

        }
        if (failcount) {
            fprintf(stderr,
                    "%s: WARNING %d of %d processed file(s) failed GOST hash sum check\n",
                    argv[0], failcount, count - errors);
        }
        exit((failcount || errors) ? 1 : 0);
    } else if (filenames_from_stdin) {
        char sum[MAX_HASH_TXT_BYTES + 1];
        char filename[PATH_MAX + 1], *end;
        while (!feof(stdin)) {
            if (!fgets(filename, PATH_MAX, stdin))
                break;
            for (end = filename; *end; end++) ;
            end--;
            for (; *end == '\n' || *end == '\r'; end--)
                *end = 0;
            if (!hash_file(&ctx, filename, sum, open_mode, hashsize)) {
                errors++;
            } else {
                printf("%s %s\n", sum, filename);
            }
        }

    } else if (optind == argc) {
        char sum[MAX_HASH_TXT_BYTES + 1];
        if (!hash_stream(&ctx, fileno(stdin), sum, hashsize)) {
            perror("stdin");
            exit(1);
        }
        printf("%s -\n", sum);
        exit(0);
    } else {
        for (i = optind; i < argc; i++) {
            char sum[MAX_HASH_TXT_BYTES + 1];
            if (!hash_file(&ctx, argv[i], sum, open_mode, hashsize)) {
                errors++;
            } else {
                printf("%s %s\n", sum, argv[i]);
            }
        }
    }
    exit(errors ? 1 : 0);
}

int hash_file(gost_hash_ctx * ctx, char *filename, char *sum, int mode,
              int hashsize)
{
    int fd;
    if ((fd = open(filename, mode)) < 0) {
        perror(filename);
        return 0;
    }
    if (!hash_stream(ctx, fd, sum, hashsize)) {
        perror(filename);
        close(fd);
        return 0;
    }
    close(fd);
    return 1;
}

int hash_stream(gost_hash_ctx * ctx, int fd, char *sum, int hashsize)
{
    unsigned char buffer[BUF_SIZE];
    ssize_t bytes;
    int i;
    start_hash(ctx, hashsize * 8);
    while ((bytes = read(fd, buffer, BUF_SIZE)) > 0) {
        hash_block(ctx, buffer, bytes);
    }
    if (bytes < 0) {
        return 0;
    }
    finish_hash(ctx, buffer);
    for (i = 0; i < hashsize; i++) {
        sprintf(sum + 2 * i, "%02x", buffer[i]);
    }
    return 1;
}

int get_line(FILE *f, char *hash, char *filename, int verbose, int *size)
{
    int i, len;
    char *ptr = filename;
    char *spacepos = NULL;

    while (!feof(f)) {
        if (!fgets(filename, PATH_MAX, f))
            return 0;
        ptr = filename;
        while (*ptr == ' ')
            ptr++;

        len = strlen(ptr);
        while (ptr[--len] == '\n' || ptr[len] == '\r')
            ptr[len] = 0;

        if (len == 0)
            goto nextline;

        spacepos = strchr(ptr, ' ');
        if (spacepos == NULL || strlen(spacepos + 1) == 0)
            goto nextline;

        *size = spacepos - ptr;

        for (i = 0; i < *size; i++) {
            if (ptr[i] < '0' || (ptr[i] > '9' && ptr[i] < 'A') ||
                (ptr[i] > 'F' && ptr[i] < 'a') || ptr[i] > 'f') {
                goto nextline;
            }
        }

        if (*size > 128 || ((*size != 64) && (*size != 128))) {
            *size = 0;
            memset(hash, 0, MAX_HASH_TXT_BYTES + 1);
        } else {
            memcpy(hash, ptr, *size);
            hash[*size] = 0;
        }
        memmove(filename, spacepos + 1, strlen(spacepos));

        *size /= 2;
        return 1;
 nextline:
        if (verbose)
            printf("Skipping line %s\n", filename);
    }
    return 0;
}
