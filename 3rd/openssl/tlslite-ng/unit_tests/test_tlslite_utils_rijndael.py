# Copyright (c) 2016, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
from __future__ import division
try:
        import unittest2 as unittest
except ImportError:
        import unittest

import tlslite.utils.rijndael as rijndael

class TestConstants(unittest.TestCase):
    def setUp(self):
        A = [[1, 1, 1, 1, 1, 0, 0, 0],
             [0, 1, 1, 1, 1, 1, 0, 0],
             [0, 0, 1, 1, 1, 1, 1, 0],
             [0, 0, 0, 1, 1, 1, 1, 1],
             [1, 0, 0, 0, 1, 1, 1, 1],
             [1, 1, 0, 0, 0, 1, 1, 1],
             [1, 1, 1, 0, 0, 0, 1, 1],
             [1, 1, 1, 1, 0, 0, 0, 1]]

        # produce log and alog tables, needed for multiplying in the
        # field GF(2^m) (generator = 3)
        alog = [1]
        for i in range(255):
            j = (alog[-1] << 1) ^ alog[-1]
            if j & 0x100 != 0:
                j ^= 0x11B
            alog.append(j)

        log = [0] * 256
        for i in range(1, 255):
            log[alog[i]] = i

        # multiply two elements of GF(2^m)
        def mul(a, b):
            if a == 0 or b == 0:
                return 0
            return alog[(log[a & 0xFF] + log[b & 0xFF]) % 255]

        # substitution box based on F^{-1}(x)
        box = [[0] * 8 for i in range(256)]
        box[1][7] = 1
        for i in range(2, 256):
            j = alog[255 - log[i]]
            for t in range(8):
                box[i][t] = (j >> (7 - t)) & 0x01

        B = [0, 1, 1, 0, 0, 0, 1, 1]

        # affine transform:  box[i] <- B + A*box[i]
        cox = [[0] * 8 for i in range(256)]
        for i in range(256):
            for t in range(8):
                cox[i][t] = B[t]
                for j in range(8):
                    cox[i][t] ^= A[t][j] * box[i][j]

        # S-boxes and inverse S-boxes
        S =  [0] * 256
        Si = [0] * 256
        for i in range(256):
            S[i] = cox[i][0] << 7
            for t in range(1, 8):
                S[i] ^= cox[i][t] << (7-t)
            Si[S[i] & 0xFF] = i

        # T-boxes
        G = [[2, 1, 1, 3],
            [3, 2, 1, 1],
            [1, 3, 2, 1],
            [1, 1, 3, 2]]

        AA = [[0] * 8 for i in range(4)]

        for i in range(4):
            for j in range(4):
                AA[i][j] = G[i][j]
                AA[i][i+4] = 1

        for i in range(4):
            pivot = AA[i][i]
            if pivot == 0:
                t = i + 1
                while AA[t][i] == 0 and t < 4:
                    t += 1
                    assert t != 4, 'G matrix must be invertible'
                    for j in range(8):
                        AA[i][j], AA[t][j] = AA[t][j], AA[i][j]
                    pivot = AA[i][i]
            for j in range(8):
                if AA[i][j] != 0:
                    AA[i][j] = alog[(255 + log[AA[i][j] & 0xFF] -
                                    log[pivot & 0xFF]) % 255]
            for t in range(4):
                if i != t:
                    for j in range(i+1, 8):
                        AA[t][j] ^= mul(AA[i][j], AA[t][i])
                    AA[t][i] = 0

        iG = [[0] * 4 for i in range(4)]

        for i in range(4):
            for j in range(4):
                iG[i][j] = AA[i][j + 4]

        def mul4(a, bs):
            if a == 0:
                return 0
            r = 0
            for b in bs:
                r <<= 8
                if b != 0:
                    r = r | mul(a, b)
            return r

        T1 = []
        T2 = []
        T3 = []
        T4 = []
        T5 = []
        T6 = []
        T7 = []
        T8 = []
        U1 = []
        U2 = []
        U3 = []
        U4 = []

        for t in range(256):
            s = S[t]
            T1.append(mul4(s, G[0]))
            T2.append(mul4(s, G[1]))
            T3.append(mul4(s, G[2]))
            T4.append(mul4(s, G[3]))

            s = Si[t]
            T5.append(mul4(s, iG[0]))
            T6.append(mul4(s, iG[1]))
            T7.append(mul4(s, iG[2]))
            T8.append(mul4(s, iG[3]))

            U1.append(mul4(t, iG[0]))
            U2.append(mul4(t, iG[1]))
            U3.append(mul4(t, iG[2]))
            U4.append(mul4(t, iG[3]))

        # round constants
        rcon = [1]
        r = 1
        for t in range(1, 30):
            r = mul(2, r)
            rcon.append(r)

        self.S = tuple(S)
        self.Si = tuple(Si)
        self.T1 = tuple(T1)
        self.T2 = tuple(T2)
        self.T3 = tuple(T3)
        self.T4 = tuple(T4)
        self.T5 = tuple(T5)
        self.T6 = tuple(T6)
        self.T7 = tuple(T7)
        self.T8 = tuple(T8)
        self.U1 = tuple(U1)
        self.U2 = tuple(U2)
        self.U3 = tuple(U3)
        self.U4 = tuple(U4)
        self.rcon = tuple(rcon)

    def test_S_box(self):
        self.assertEqual(rijndael.S, self.S)

    def test_Si_box(self):
        self.assertEqual(rijndael.Si, self.Si)

    def test_T1(self):
        self.assertEqual(rijndael.T1, self.T1)

    def test_T2(self):
        self.assertEqual(rijndael.T2, self.T2)

    def test_T3(self):
        self.assertEqual(rijndael.T3, self.T3)

    def test_T4(self):
        self.assertEqual(rijndael.T4, self.T4)

    def test_T5(self):
        self.assertEqual(rijndael.T5, self.T5)

    def test_T6(self):
        self.assertEqual(rijndael.T6, self.T6)

    def test_T7(self):
        self.assertEqual(rijndael.T7, self.T7)

    def test_T8(self):
        self.assertEqual(rijndael.T8, self.T8)

    def test_U1(self):
        self.assertEqual(rijndael.U1, self.U1)

    def test_U2(self):
        self.assertEqual(rijndael.U2, self.U2)

    def test_U3(self):
        self.assertEqual(rijndael.U3, self.U3)

    def test_U4(self):
        self.assertEqual(rijndael.U4, self.U4)

    def test_rcon(self):
        self.assertEqual(rijndael.rcon, self.rcon)

class TestSelfDecryptEncrypt(unittest.TestCase):
    def enc_dec(self, k_len, b_len):
        plaintext = bytearray(b'b' * b_len)
        cipher = rijndael.Rijndael(bytearray(b'a' * k_len), b_len)
        self.assertEqual(plaintext,
                         cipher.decrypt(cipher.encrypt(plaintext)))

    def test_16_16(self):
        self.enc_dec(16, 16)

    def test_16_24(self):
        self.enc_dec(16, 24)

    def test_16_32(self):
        self.enc_dec(16, 32)

    def test_24_16(self):
        self.enc_dec(24, 16)

    def test_24_24(self):
        self.enc_dec(24, 24)

    def test_24_32(self):
        self.enc_dec(24, 32)

    def test_32_16(self):
        self.enc_dec(32, 16)

    def test_32_24(self):
        self.enc_dec(32, 24)

    def test_32_32(self):
        self.enc_dec(32, 32)

