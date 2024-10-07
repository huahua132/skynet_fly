# Copyright (c) 2017, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest
from tlslite.utils.dns_utils import is_valid_hostname

class TestIsValidHostname(unittest.TestCase):
    def test_example(self):
        self.assertTrue(is_valid_hostname(b'example.com'))

    def test_ip(self):
        self.assertFalse(is_valid_hostname(b'192.168.0.1'))

    def test_ip_dot(self):
        self.assertFalse(is_valid_hostname(b'192.168.0.1.'))

    def test_ip_lookalike_hostname(self):
        self.assertTrue(is_valid_hostname(b'192.168.example.com'))

    def test_with_tld_dot(self):
        self.assertTrue(is_valid_hostname(b'example.com.'))

    def test_hostname_alone(self):
        self.assertTrue(is_valid_hostname(b'localhost'))

    def test_very_long_hostname(self):
        self.assertFalse(is_valid_hostname(b'a' * 250 + b'.example.com'))

    def test_very_long_host(self):
        self.assertFalse(is_valid_hostname(b'a' * 70 + b'.example.com'))

    def test_long_hostname(self):
        self.assertTrue(is_valid_hostname(b'a' * 60 + b'.example.com'))

