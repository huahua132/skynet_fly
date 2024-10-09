# Copyright (c) 2015, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.compat import remove_whitespace

class TestRemoveWhitespace(unittest.TestCase):
    def test_no_remove(self):
        text = "somestring"
        self.assertEqual(text, remove_whitespace(text))

    def test_newline(self):
        text = """some
                  thing"""
        self.assertEqual("something", remove_whitespace(text))

    def test_remove_begginning(self):
        text = "   some  thing  "
        self.assertEqual("something", remove_whitespace(text))
