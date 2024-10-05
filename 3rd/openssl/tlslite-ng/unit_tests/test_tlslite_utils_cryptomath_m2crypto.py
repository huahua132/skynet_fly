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
import sys
try:
    # Python 2
    reload
except NameError:
    try:
        # Python >= 3.4
        from importlib import reload
    except ImportError:
        # Python <= 3.3
        from imp import reload
try:
    import __builtin__ as builtins
except ImportError:
    import builtins

real_open = builtins.open

class magic_open(object):
    def __init__(self, *args, **kwargs):
        self.args = args
        self.kwargs = kwargs

    def __enter__(self):
        if self.args[0] == '/proc/sys/crypto/fips_enabled':
            m = mock.MagicMock()
            m.read.return_value = '1'
            self.f = m
            return m
        else:
            self.f = real_open(*self.args, **self.kwargs)
            return self.f

    def __exit__(self, exc_type, exc_value, exc_traceback):
        self.f.close()

class magic_open_error(object):
    def __init__(self, *args, **kwargs):
        self.args = args
        self.kwargs = kwargs

    def __enter__(self):
        if self.args[0] == '/proc/sys/crypto/fips_enabled':
            m = mock.MagicMock()
            self.f = m
            raise IOError(12)
        else:
            self.f = real_open(*self.args, **self.kwargs)
            return self.f

    def __exit__(self, exc_type, exc_value, exc_traceback):
        self.f.close()


class TestM2CryptoLoaded(unittest.TestCase):
    def test_import_without_m2crypto(self):
        with mock.patch.dict('sys.modules', {'M2Crypto': None}):
            import tlslite.utils.cryptomath
            reload(tlslite.utils.cryptomath)
            from tlslite.utils.cryptomath import m2cryptoLoaded
            self.assertFalse(m2cryptoLoaded)

    def test_import_with_m2crypto(self):
        fake_m2 = mock.MagicMock()

        with mock.patch.dict('sys.modules', {'M2Crypto': fake_m2}):
            import tlslite.utils.cryptomath
            reload(tlslite.utils.cryptomath)
            from tlslite.utils.cryptomath import m2cryptoLoaded
            self.assertTrue(m2cryptoLoaded)

    def test_import_with_m2crypto_in_fips_mode(self):
        fake_m2 = mock.MagicMock()

        with mock.patch.dict('sys.modules', {'M2Crypto': fake_m2}):
            with mock.patch.object(builtins, 'open', magic_open):
                import tlslite.utils.cryptomath
                reload(tlslite.utils.cryptomath)
                from tlslite.utils.cryptomath import m2cryptoLoaded
                self.assertFalse(m2cryptoLoaded)

    def test_import_with_m2crypto_in_container(self):
        fake_m2 = mock.MagicMock()

        with mock.patch.dict('sys.modules', {'M2Crypto': fake_m2}):
            with mock.patch.object(builtins, 'open', magic_open_error):
                import tlslite.utils.cryptomath
                reload(tlslite.utils.cryptomath)
                from tlslite.utils.cryptomath import m2cryptoLoaded
                self.assertTrue(m2cryptoLoaded)

    @classmethod
    def tearDownClass(cls):
        import tlslite.utils.cryptomath
        reload(tlslite.utils.cryptomath)
