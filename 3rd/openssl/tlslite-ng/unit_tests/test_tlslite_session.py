# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.session import Session

class TestSession(unittest.TestCase):

    def test___init__(self):
        session = Session()

        self.assertIsNotNone(session)
        self.assertFalse(session.resumable)
        self.assertFalse(session.encryptThenMAC)
        self.assertFalse(session.extendedMasterSecret)

    def test_create(self):
        session = Session()
        session.create(masterSecret=1,
                       sessionID=2,
                       cipherSuite=3,
                       srpUsername=4,
                       clientCertChain=5,
                       serverCertChain=6,
                       tackExt=7,
                       tackInHelloExt=8,
                       serverName=9)

        self.assertEqual(session.masterSecret, 1)
        self.assertEqual(session.sessionID, 2)
        self.assertEqual(session.cipherSuite, 3)
        self.assertEqual(session.srpUsername, 4)
        self.assertEqual(session.clientCertChain, 5)
        self.assertEqual(session.serverCertChain, 6)
        self.assertEqual(session.tackExt, 7)
        self.assertEqual(session.tackInHelloExt, 8)
        self.assertEqual(session.serverName, 9)

        self.assertTrue(session.resumable)
        self.assertFalse(session.encryptThenMAC)
        self.assertFalse(session.extendedMasterSecret)

    def test_create_with_new_additions(self):
        session = Session()
        session.create(1, 2, 3, 4, 5, 6, 7, 8, 9,
                       encryptThenMAC=10,
                       extendedMasterSecret=11)

        self.assertEqual(session.encryptThenMAC, 10)
        self.assertEqual(session.extendedMasterSecret, 11)

