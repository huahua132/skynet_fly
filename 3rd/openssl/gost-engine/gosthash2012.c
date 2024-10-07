/*
 * GOST R 34.11-2012 core functions.
 *
 * Copyright (c) 2013 Cryptocom LTD.
 * This file is distributed under the same license as OpenSSL.
 *
 * Author: Alexey Degtyarev <alexey@renatasystems.org>
 *
 */

#include "gosthash2012.h"
#if defined(__x86_64__) || defined(__e2k__)
# ifdef _MSC_VER
#  include <intrin.h>
# else
#  include <x86intrin.h>
# endif
#endif

#if defined(_WIN32) || defined(_WINDOWS)
# define INLINE __inline
#else
# define INLINE inline
#endif

#define BSWAP64(x) \
    (((x & 0xFF00000000000000ULL) >> 56) | \
     ((x & 0x00FF000000000000ULL) >> 40) | \
     ((x & 0x0000FF0000000000ULL) >> 24) | \
     ((x & 0x000000FF00000000ULL) >>  8) | \
     ((x & 0x00000000FF000000ULL) <<  8) | \
     ((x & 0x0000000000FF0000ULL) << 24) | \
     ((x & 0x000000000000FF00ULL) << 40) | \
     ((x & 0x00000000000000FFULL) << 56))

/*
 * Initialize gost2012 hash context structure
 */
void init_gost2012_hash_ctx(gost2012_hash_ctx * CTX,
                            const unsigned int digest_size)
{
    memset(CTX, 0, sizeof(gost2012_hash_ctx));

    CTX->digest_size = digest_size;
    /*
     * IV for 512-bit hash should be 0^512
     * IV for 256-bit hash should be (00000001)^64
     *
     * It's already zeroed when CTX is cleared above, so we only
     * need to set it to 0x01-s for 256-bit hash.
     */
    if (digest_size == 256)
        memset(&CTX->h, 0x01, sizeof(uint512_u));
}

static INLINE void pad(gost2012_hash_ctx * CTX)
{
    memset(&(CTX->buffer.B[CTX->bufsize]), 0, sizeof(CTX->buffer) - CTX->bufsize);
    CTX->buffer.B[CTX->bufsize] = 1;

}

static INLINE void add512(union uint512_u * RESTRICT x,
                          const union uint512_u * RESTRICT y)
{
#ifndef __GOST3411_BIG_ENDIAN__
    unsigned int CF = 0;
    unsigned int i;

# ifdef HAVE_ADDCARRY_U64
    for (i = 0; i < 8; i++)
        CF = _addcarry_u64(CF, x->QWORD[i] , y->QWORD[i], &(x->QWORD[i]));
# else
    for (i = 0; i < 8; i++) {
        const unsigned long long left = x->QWORD[i];
        unsigned long long sum;

        sum = left + y->QWORD[i] + CF;
        /*
         * (sum == left): is noop, because it's possible only
         * when `left' is added with `0 + 0' or with `ULLONG_MAX + 1',
         * in that case `CF' (carry) retain previous value, which is correct,
         * because when `left + 0 + 0' there was no overflow (thus no carry),
         * and when `left + ULLONG_MAX + 1' value is wrapped back to
         * itself with overflow, thus creating carry.
         *
         * (sum != left):
         * if `sum' is not wrapped (sum > left) there should not be carry,
         * if `sum' is wrapped (sum < left) there should be carry.
         */
        if (sum != left)
            CF = (sum < left);
        x->QWORD[i] = sum;
    }
# endif /* !__x86_64__ */
#else /* __GOST3411_BIG_ENDIAN__ */
    const unsigned char *yp;
    unsigned char *xp;
    unsigned int i;
    int buf;

    xp = (unsigned char *)&x[0];
    yp = (const unsigned char *)&y[0];

    buf = 0;
    for (i = 0; i < 64; i++) {
        buf = xp[i] + yp[i] + (buf >> 8);
        xp[i] = (unsigned char)buf & 0xFF;
    }
#endif /* __GOST3411_BIG_ENDIAN__ */
}

static void g(union uint512_u *h, const union uint512_u * RESTRICT N,
              const union uint512_u * RESTRICT m)
{
#ifdef __GOST3411_HAS_SSE2__
    __m128i xmm0, xmm2, xmm4, xmm6; /* XMMR0-quadruple */
    __m128i xmm1, xmm3, xmm5, xmm7; /* XMMR1-quadruple */
    unsigned int i;

    LOAD(N, xmm0, xmm2, xmm4, xmm6);
    XLPS128M(h, xmm0, xmm2, xmm4, xmm6);

    ULOAD(m, xmm1, xmm3, xmm5, xmm7);
    XLPS128R(xmm0, xmm2, xmm4, xmm6, xmm1, xmm3, xmm5, xmm7);

    for (i = 0; i < 11; i++)
        ROUND128(i, xmm0, xmm2, xmm4, xmm6, xmm1, xmm3, xmm5, xmm7);

    XLPS128M((&C[11]), xmm0, xmm2, xmm4, xmm6);
    X128R(xmm0, xmm2, xmm4, xmm6, xmm1, xmm3, xmm5, xmm7);

    X128M(h, xmm0, xmm2, xmm4, xmm6);
    ULOAD(m, xmm1, xmm3, xmm5, xmm7);
    X128R(xmm0, xmm2, xmm4, xmm6, xmm1, xmm3, xmm5, xmm7);

    STORE(h, xmm0, xmm2, xmm4, xmm6);
# ifndef __i386__
    /* Restore the Floating-point status on the CPU */
    /* This is only required on MMX, but EXTRACT32 is using MMX */
    _mm_empty();
# endif
#else
    union uint512_u Ki, data;
    unsigned int i;

    XLPS(h, N, (&data));

    /* Starting E() */
    Ki = data;
    XLPS((&Ki), ((const union uint512_u *)&m[0]), (&data));

    for (i = 0; i < 11; i++)
        ROUND(i, (&Ki), (&data));

    XLPS((&Ki), (&C[11]), (&Ki));
    X((&Ki), (&data), (&data));
    /* E() done */

    X((&data), h, (&data));
    X((&data), m, h);
#endif
}

static INLINE void stage2(gost2012_hash_ctx * CTX, const union uint512_u *data)
{
    g(&(CTX->h), &(CTX->N), data);

    add512(&(CTX->N), &buffer512);
    add512(&(CTX->Sigma), data);
}

static INLINE void stage3(gost2012_hash_ctx * CTX)
{
    pad(CTX);
    g(&(CTX->h), &(CTX->N), &(CTX->buffer));
    add512(&(CTX->Sigma), &CTX->buffer);

    memset(&(CTX->buffer.B[0]), 0, sizeof(uint512_u));
#ifndef __GOST3411_BIG_ENDIAN__
    CTX->buffer.QWORD[0] = CTX->bufsize << 3;
#else
    CTX->buffer.QWORD[0] = BSWAP64(CTX->bufsize << 3);
#endif
    add512(&(CTX->N), &(CTX->buffer));

    g(&(CTX->h), &buffer0, &(CTX->N));
    g(&(CTX->h), &buffer0, &(CTX->Sigma));
}

/*
 * Hash block of arbitrary length
 *
 */
void gost2012_hash_block(gost2012_hash_ctx * CTX,
                         const unsigned char *data, size_t len)
{
    register size_t bufsize = CTX->bufsize;

    if (bufsize == 0) {
        while (len >= 64) {
            memcpy(&CTX->buffer.B[0], data, 64);
            stage2(CTX, &(CTX->buffer));
            data += 64;
            len -= 64;
        }
    }

    while (len) {
        register size_t chunksize = 64 - bufsize;
        if (chunksize > len)
            chunksize = len;

        memcpy(&CTX->buffer.B[bufsize], data, chunksize);

        bufsize += chunksize;
        len -= chunksize;
        data += chunksize;

        if (bufsize == 64) {
            stage2(CTX, &(CTX->buffer) );
            bufsize = 0;
        }
    }
    CTX->bufsize = bufsize;
}

/*
 * Compute hash value from current state of ctx
 * state of hash ctx becomes invalid and cannot be used for further
 * hashing.
 */
void gost2012_finish_hash(gost2012_hash_ctx * CTX, unsigned char *digest)
{
    stage3(CTX);

    CTX->bufsize = 0;

    if (CTX->digest_size == 256)
        memcpy(digest, &(CTX->h.QWORD[4]), 32);
    else
        memcpy(digest, &(CTX->h.QWORD[0]), 64);
}
