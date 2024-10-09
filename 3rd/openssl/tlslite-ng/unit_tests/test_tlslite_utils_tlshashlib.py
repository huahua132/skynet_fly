# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest
try:
    import mock
    from mock import call
except ImportError:
    import unittest.mock as mock
    from unittest.mock import call

class TestTLSHashlib(unittest.TestCase):

    def test_in_fips_mode(self):
        def m(*args, **kwargs):
            if 'usedforsecurity' not in kwargs:
                raise ValueError("MD5 disabled in FIPS mode")

        with mock.patch('hashlib.md5', m):
            from tlslite.utils.tlshashlib import md5
            md5()
