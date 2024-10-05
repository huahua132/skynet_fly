# Copyright (c) 2019, Alexander Sosedkin
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

import sys

from hypothesis import given, assume, settings
from hypothesis.strategies import binary, integers, tuples

from tlslite.utils import cryptomath

import tlslite.utils.python_tripledes
py_3des = tlslite.utils.python_tripledes.new


HYP_SETTINGS = {'deadline': None} if sys.version_info > (2, 7) else {}


class TestTripleDES(unittest.TestCase):
    _given = given(binary(min_size=24, max_size=24),          # key
                   binary(min_size=8, max_size=8),            # iv
                   binary(min_size=13*8, max_size=13*8),      # plaintext
                   (tuples(integers(0, 13), integers(0, 13))  # split points
                       .filter(lambda split_pts: split_pts[0] <= split_pts[1])
                       .map(lambda lengths: [i * 8 for i in lengths])))

    def split_test(self, key, iv, plaintext, split_points, make_impl=py_3des):
        i, j = split_points

        ciphertext = make_impl(key, iv).encrypt(plaintext)
        self.assertEqual(make_impl(key, iv).decrypt(ciphertext), plaintext)

        impl = make_impl(key, iv)
        pl1, pl2, pl3 = plaintext[:i], plaintext[i:j], plaintext[j:]
        ci1, ci2, ci3 = impl.encrypt(pl1), impl.encrypt(pl2), impl.encrypt(pl3)
        self.assertEqual(ci1 + ci2 + ci3, ciphertext)

        impl = make_impl(key, iv)
        pl1, pl2, pl3 = impl.decrypt(ci1), impl.decrypt(ci2), impl.decrypt(ci3)
        self.assertEqual(pl1 + pl2 + pl3, plaintext)

        return ciphertext

    @_given
    @settings(**HYP_SETTINGS)
    def test_python(self, key, iv, plaintext, split_points):
        self.split_test(key, iv, plaintext, split_points)

    @unittest.skipIf(not cryptomath.m2cryptoLoaded, "requires M2Crypto")
    @_given
    @settings(**HYP_SETTINGS)
    def test_python_vs_mcrypto(self, key, iv, plaintext, split_points):
        import tlslite.utils.openssl_tripledes
        m2_3des = lambda k, iv: tlslite.utils.openssl_tripledes.new(k, 2, iv)

        py_res = self.split_test(key, iv, plaintext, split_points, py_3des)
        m2_res = self.split_test(key, iv, plaintext, split_points, m2_3des)
        self.assertEqual(py_res, m2_res)

    @unittest.skipIf(not cryptomath.pycryptoLoaded, "requires pycrypto")
    @_given
    @settings(**HYP_SETTINGS)
    def test_python_vs_pycrypto(self, key, iv, plaintext, split_points):
        import tlslite.utils.pycrypto_tripledes
        pc_3des = lambda k, iv: tlslite.utils.pycrypto_tripledes.new(k, 2, iv)

        try:
            py_res = self.split_test(key, iv, plaintext, split_points, py_3des)
            pc_res = self.split_test(key, iv, plaintext, split_points, pc_3des)
            self.assertEqual(py_res, pc_res)
        except ValueError as e:
            # pycrypto deliberately rejects weak 3DES keys, skip such keys
            assume(e.args != ('Triple DES key degenerates to single DES',))
            raise
