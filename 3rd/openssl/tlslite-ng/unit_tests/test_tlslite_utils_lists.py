# Copyright (c) 2016, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.lists import getFirstMatching, to_str_delimiter

class TestGetFirstMatching(unittest.TestCase):
    def test_empty_list(self):
        self.assertIsNone(getFirstMatching([], [1, 2, 3]))

    def test_first_matching(self):
        self.assertEqual(getFirstMatching([1, 7, 8, 9], [1, 2, 3]), 1)

    def test_last_matching(self):
        self.assertEqual(getFirstMatching([7, 8, 9, 1], [1, 2, 3]), 1)

    def test_no_matching(self):
        self.assertIsNone(getFirstMatching([7, 8, 9], [1, 2, 3]))

    def test_no_list(self):
        self.assertIsNone(getFirstMatching(None, [1, 2, 3]))

    def test_empty_matches(self):
        self.assertIsNone(getFirstMatching([1, 2, 3], []))

    def test_no_matches(self):
        with self.assertRaises(AssertionError):
            getFirstMatching([1, 2, 3], None)


class TestToStrDelimiter(unittest.TestCase):
    def test_empty_list(self):
        self.assertEqual("", to_str_delimiter([]))

    def test_one_element(self):
        self.assertEqual("12", to_str_delimiter([12]))

    def test_two_elements(self):
        self.assertEqual("12 or 13", to_str_delimiter([12, 13]))

    def test_three_elements(self):
        self.assertEqual("12, 13 or 14", to_str_delimiter([12, 13, 14]))

    def test_with_strings(self):
        self.assertEqual("abc, def or ghi",
                         to_str_delimiter(['abc', 'def', 'ghi']))
