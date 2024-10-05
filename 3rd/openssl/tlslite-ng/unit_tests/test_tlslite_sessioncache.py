# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.sessioncache import SessionCache

class TestGetAttributeAfterPurge(unittest.TestCase):
    """
    This tests the following scenario

    Add an entry to the session cache
    wait until the cache should have expired
    fetch the entry for the session cache.

    """

    def setUp(self):
        # set maxAge to 0 to have an immediate expire
        self.session_cache = SessionCache(maxAge=0)

    def test_fetch_after_expire(self):
        key = bytearray(b'hello world')
        self.session_cache[key] = "42"
        with self.assertRaises(KeyError):
            self.session_cache[key] 

class TestFillLinkedList(unittest.TestCase):
    """ check what happens if the linked list gets full
    """

    def setUp(self):
        self.session_cache = SessionCache(maxEntries = 10)

    def test_fill_linked_list(self):
        """this test should not throw an exception"""
        for i in range(20):
            key = bytearray(b'prefill-') + bytearray(str(i), "ascii")
            self.session_cache[key] = "forty-two"


if __name__ == '__main__':
    unittest.main()
