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

from tlslite.x509 import X509
from tlslite.utils.python_ecdsakey import Python_ECDSAKey
from tlslite.utils.python_dsakey import Python_DSAKey
from tlslite.utils.python_eddsakey import Python_EdDSAKey
from tlslite.x509certchain import X509CertChain

class Test_DSA_X509(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (
                "-----BEGIN CERTIFICATE-----\n"
                "MIIBQjCCAQACFFyBKCftN0cXDwuMuZWvtW7uG2xGMAsGCWCGSAFlAwQDAjAUMRIw\n"
                "EAYDVQQDDAlsb2NhbGhvc3QwHhcNMjAwOTAzMDkwNzUxWhcNMjAxMDAzMDkwNzUx\n"
                "WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwgY4wZwYHKoZIzjgEATBcAiEAmeFbCUhV\n"
                "UZgVpljXObhmRaQYIQ12YSr9zlCja2kpTiUCFQCfCyagvEDkgK5nHqscaYlF32ek\n"
                "RwIgYgpNP8JjVxfJ4P3IErO07qqzWS21hSyMhsaCN0an0OsDIwACICUjj3Np+JO4\n"
                "2v8Mc8oH6T8yNd5X0ssy8XdK3Bo9nfNpMAsGCWCGSAFlAwQDAgMvADAsAhRgjSkX\n"
                "k9nkSQc2P3uA+fFEH2OOnAIUZnBeKDjTEMawkvRSXoGHhA93qQ4=\n"
                "-----END CERTIFICATE-----\n")

    def test_pem(self):
        x509 = X509()
        x509.parse(self.data)

        self.assertIsNotNone(x509.publicKey)
        self.assertIsInstance(x509.publicKey, Python_DSAKey)
        self.assertEqual(x509.publicKey.public_key,
                16798405106129606882295006910154614336997455047535738179977898112652777747305)
        self.assertEqual(x509.publicKey.p,
                69602034731989554929546346371414762967051205729581487767213360812510562307621)
        self.assertEqual(x509.publicKey.q,
                907978205720450240238233398695599264980368073799)
        self.assertEqual(x509.publicKey.g,
                44344860785224683582210580276798141855549498608976964582640232671615126065387)


class TestX509(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (
            "-----BEGIN CERTIFICATE-----\n"
            "MIIBbTCCARSgAwIBAgIJAPM58cskyK+yMAkGByqGSM49BAEwFDESMBAGA1UEAwwJ\n"
            "bG9jYWxob3N0MB4XDTE3MTAyMzExNDI0MVoXDTE3MTEyMjExNDI0MVowFDESMBAG\n"
            "A1UEAwwJbG9jYWxob3N0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEyDRjEAJe\n"
            "3F5T62MyZbhjoJnPLGL2nrTthLFymBupZ2IbnWYnqVWDkT/L6i8sQhf2zCLrlSjj\n"
            "1kn7ERqPx/KZyqNQME4wHQYDVR0OBBYEFPfFTUg9o3t6ehLsschSnC8Te8oaMB8G\n"
            "A1UdIwQYMBaAFPfFTUg9o3t6ehLsschSnC8Te8oaMAwGA1UdEwQFMAMBAf8wCQYH\n"
            "KoZIzj0EAQNIADBFAiA6p0YM5ZzfW+klHPRU2r13/IfKgeRfDR3dtBngmPvxUgIh\n"
            "APTeSDeJvYWVBLzyrKTeSerNDKKHU2Rt7sufipv76+7s\n"
            "-----END CERTIFICATE-----\n")

    def test_pem(self):
        x509 = X509()
        x509.parse(self.data)

        self.assertIsNotNone(x509.publicKey)
        self.assertIsInstance(x509.publicKey, Python_ECDSAKey)
        self.assertEqual(x509.publicKey.public_key.pubkey.point.x(),
            90555129468518880658937518803653422065597446465131062487534800201457796212578)
        self.assertEqual(x509.publicKey.public_key.pubkey.point.y(),
            12490546948316647166662676770106859255378658810545502161335656899238893361610)
        self.assertEqual(x509.publicKey.curve_name, "NIST256p")

    def test_hash(self):
        x509_1 = X509()
        x509_1.parse(self.data)

        x509_2 = X509()
        x509_2.parse(self.data)

        self.assertEqual(hash(x509_1), hash(x509_2))
        self.assertEqual(x509_1, x509_2)

class TestX509CertChain(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (
            "-----BEGIN CERTIFICATE-----\n"
            "MIIBbTCCARSgAwIBAgIJAPM58cskyK+yMAkGByqGSM49BAEwFDESMBAGA1UEAwwJ\n"
            "bG9jYWxob3N0MB4XDTE3MTAyMzExNDI0MVoXDTE3MTEyMjExNDI0MVowFDESMBAG\n"
            "A1UEAwwJbG9jYWxob3N0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEyDRjEAJe\n"
            "3F5T62MyZbhjoJnPLGL2nrTthLFymBupZ2IbnWYnqVWDkT/L6i8sQhf2zCLrlSjj\n"
            "1kn7ERqPx/KZyqNQME4wHQYDVR0OBBYEFPfFTUg9o3t6ehLsschSnC8Te8oaMB8G\n"
            "A1UdIwQYMBaAFPfFTUg9o3t6ehLsschSnC8Te8oaMAwGA1UdEwQFMAMBAf8wCQYH\n"
            "KoZIzj0EAQNIADBFAiA6p0YM5ZzfW+klHPRU2r13/IfKgeRfDR3dtBngmPvxUgIh\n"
            "APTeSDeJvYWVBLzyrKTeSerNDKKHU2Rt7sufipv76+7s\n"
            "-----END CERTIFICATE-----\n")

    def test_pem(self):
        x509cc = X509CertChain()
        x509cc.parsePemList(self.data)

    def test_hash(self):
        x509cc1 = X509CertChain()
        x509cc1.parsePemList(self.data)

        x509cc2 = X509CertChain()
        x509cc2.parsePemList(self.data)

        self.assertEqual(hash(x509cc1), hash(x509cc2))
        self.assertEqual(x509cc1, x509cc2)


class TestX509WithEdDSA(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (
            "-----BEGIN CERTIFICATE-----\n"
            "MIIBPDCB76ADAgECAhQkqENccCvOQyI4iKFuuOKwl860bTAFBgMrZXAwFDESMBAG\n"
            "A1UEAwwJbG9jYWxob3N0MB4XDTIxMDcyNjE0MjcwN1oXDTIxMDgyNTE0MjcwN1ow\n"
            "FDESMBAGA1UEAwwJbG9jYWxob3N0MCowBQYDK2VwAyEA1KMGmAZealfgakBuCx/E\n"
            "n69fo072qm90eM40ulGex0ajUzBRMB0GA1UdDgQWBBTHKWv5l/SxnkkYJhh5r3Pv\n"
            "ESAh1DAfBgNVHSMEGDAWgBTHKWv5l/SxnkkYJhh5r3PvESAh1DAPBgNVHRMBAf8E\n"
            "BTADAQH/MAUGAytlcANBAF/vSBfOHAdRl29sWDTkuqy1dCuSf7j7jKE/Be8Fk7xs\n"
            "WteXJmIa0HlRAZjxNfWbsSGLnTYbsGTbxKx3QU9H9g0=\n"
            "-----END CERTIFICATE-----\n")
        cls.priv_key = (
            "-----BEGIN PRIVATE KEY-----\n"
            "MC4CAQAwBQYDK2VwBCIEIAjtEwCECqbot5RZxSmiNDWcPp+Xc9Y9WJcUhti3JgSP\n"
            "-----END PRIVATE KEY-----\n")
        cls.ed448_data = (
            "-----BEGIN CERTIFICATE-----\n"
            "MIIBiDCCAQigAwIBAgIUZoaDDgE5Cy2GuAMtk4lnsmrPF04wBQYDK2VxMBQxEjAQ\n"
            "BgNVBAMMCWxvY2FsaG9zdDAeFw0yMTA3MjYxODAzMzhaFw0yMTA4MjUxODAzMzha\n"
            "MBQxEjAQBgNVBAMMCWxvY2FsaG9zdDBDMAUGAytlcQM6AKxTNGJ39O4kUx7BopPK\n"
            "prb1Jkoo0csq0Cmpa+VhpDlbR9/gVsb3pchexzjxXyRkNv71naHmOkQvAKNTMFEw\n"
            "HQYDVR0OBBYEFBb153yRh5IZOfBxoakGVuviFKujMB8GA1UdIwQYMBaAFBb153yR\n"
            "h5IZOfBxoakGVuviFKujMA8GA1UdEwEB/wQFMAMBAf8wBQYDK2VxA3MAiXEqTPRb\n"
            "u+56ebfiGjdE++H+YvHVxxxycqKAIAikfsLFfw2LUGQVBMhl+nzS4zRDOKa34uGz\n"
            "DwEApFuOWurH/y8zqM5NFyXfwbHRlhG4xwUet52CbrtC7Dy1HYnvWdEjbKDSJXpJ\n"
            "MmNSiO0oBtQ62CsA\n"
            "-----END CERTIFICATE-----\n")

    def test_pem_cert(self):
        x509 = X509()
        x509.parse(self.data)

        self.assertIsNotNone(x509.publicKey)
        self.assertIsInstance(x509.publicKey, Python_EdDSAKey)
        self.assertEqual(x509.certAlg, "Ed25519")

    def test_pem_ed448_cert(self):
        x509 = X509()
        x509.parse(self.ed448_data)

        self.assertIsNotNone(x509.publicKey)
        self.assertIsInstance(x509.publicKey, Python_EdDSAKey)
        self.assertEqual(x509.certAlg, "Ed448")
