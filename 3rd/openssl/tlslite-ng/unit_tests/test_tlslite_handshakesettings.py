# Author: Hubert Kario (c) 2014
# see LICENCE file for legal information regarding use of this file

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest
try:
    import mock
except ImportError:
    import unittest.mock as mock

from tlslite.handshakesettings import HandshakeSettings, Keypair, VirtualHost

class TestHandshakeSettings(unittest.TestCase):
    def test___init__(self):
        hs = HandshakeSettings()

        self.assertIsNotNone(hs)

    def test_validate(self):
        hs = HandshakeSettings()
        newHS = hs.validate()

        self.assertIsNotNone(newHS)
        self.assertIsNot(hs, newHS)

    def test_minKeySize_too_small(self):
        hs = HandshakeSettings()
        hs.minKeySize = 511

        with self.assertRaises(ValueError):
            hs.validate()

    def test_minKeySize_too_large(self):
        hs = HandshakeSettings()
        hs.minKeySize = 16385

        with self.assertRaises(ValueError):
            hs.validate()

    def test_maxKeySize_too_small(self):
        hs = HandshakeSettings()
        hs.maxKeySize = 511

        with self.assertRaises(ValueError):
            hs.validate()

    def test_maxKeySize_too_large(self):
        hs = HandshakeSettings()
        hs.maxKeySize = 16385

        with self.assertRaises(ValueError):
            hs.validate()

    def test_maxKeySize_smaller_than_minKeySize(self):
        hs = HandshakeSettings()
        hs.maxKeySize = 1024
        hs.minKeySize = 2048

        with self.assertRaises(ValueError):
            hs.validate()

    def test_cipherNames_with_unknown_name(self):
        hs = HandshakeSettings()
        hs.cipherNames = ["aes256"]

        newHs = hs.validate()

        self.assertEqual(["aes256"], newHs.cipherNames)

    def test_cipherNames_with_unknown_name(self):
        hs = HandshakeSettings()
        hs.cipherNames = ["camellia256gcm", "aes256"]

        with self.assertRaises(ValueError):
            hs.validate()

    def test_cipherNames_empty(self):
        hs = HandshakeSettings()
        hs.cipherNames = []

        with self.assertRaises(ValueError):
            hs.validate()

    def test_certificateTypes_empty(self):
        hs = HandshakeSettings()
        hs.certificateTypes = []

        with self.assertRaises(ValueError):
            hs.validate()

    def test_certificateTypes_with_unknown_type(self):
        hs = HandshakeSettings()
        hs.certificateTypes = [0, 42]

        with self.assertRaises(ValueError):
            hs.validate()

    def test_cipherImplementations_empty(self):
        hs = HandshakeSettings()
        hs.cipherImplementations = []

        with self.assertRaises(ValueError):
            hs.validate()

    def test_cipherImplementations_with_unknown_implementations(self):
        hs = HandshakeSettings()
        hs.cipherImplementations = ["openssl", "NSS"]

        with self.assertRaises(ValueError):
            hs.validate()

    def test_minVersion_higher_than_maxVersion(self):
        hs = HandshakeSettings()
        hs.minVersion = (3, 3)
        hs.maxVersion = (3, 0)

        with self.assertRaises(ValueError):
            hs.validate()

    def test_minVersion_with_unknown_version(self):
        hs = HandshakeSettings()
        hs.minVersion = (2, 0)

        with self.assertRaises(ValueError):
            hs.validate()

    def test_maxVersion_with_unknown_version(self):
        hs = HandshakeSettings()
        hs.maxVersion = (3, 5)

        with self.assertRaises(ValueError):
            hs.validate()

    def test_maxVersion_without_TLSv1_2(self):
        hs = HandshakeSettings()
        hs.maxVersion = (3, 2)

        self.assertTrue('sha256' in hs.macNames)

        new_hs = hs.validate()

        self.assertFalse("sha256" in new_hs.macNames)

    def test_getCertificateTypes(self):
        hs = HandshakeSettings()

        self.assertEqual([0], hs.getCertificateTypes())

    def test_getCertificateTypes_with_unsupported_type(self):
        hs = HandshakeSettings()
        hs.certificateTypes = ["x509", "openpgp"]

        with self.assertRaises(AssertionError):
            hs.getCertificateTypes()

    def test_useEncryptThenMAC(self):
        hs = HandshakeSettings()
        self.assertTrue(hs.useEncryptThenMAC)

        hs.useEncryptThenMAC = False

        n_hs = hs.validate()

        self.assertFalse(n_hs.useEncryptThenMAC)

    def test_useEncryptThenMAC_with_wrong_value(self):
        hs = HandshakeSettings()
        hs.useEncryptThenMAC = None

        with self.assertRaises(ValueError):
            hs.validate()

    def test_useExtendedMasterSecret(self):
        hs = HandshakeSettings()
        self.assertTrue(hs.useExtendedMasterSecret)

        hs.useExtendedMasterSecret = False

        n_hs = hs.validate()

        self.assertFalse(n_hs.useExtendedMasterSecret)

    def test_useExtendedMasterSecret_with_wrong_value(self):
        hs = HandshakeSettings()
        hs.useExtendedMasterSecret = None

        with self.assertRaises(ValueError):
            hs.validate()

    def test_requireExtendedMasterSecret(self):
        hs = HandshakeSettings()
        self.assertFalse(hs.requireExtendedMasterSecret)

        hs.requireExtendedMasterSecret = True

        n_hs = hs.validate()

        self.assertTrue(n_hs.requireExtendedMasterSecret)

    def test_requireExtendedMasterSecret_with_wrong_value(self):
        hs = HandshakeSettings()
        hs.requireExtendedMasterSecret = None

        with self.assertRaises(ValueError):
            hs.validate()

    def test_requireExtendedMasterSecret_with_incompatible_use_EMS(self):
        hs = HandshakeSettings()
        hs.useExtendedMasterSecret = False
        hs.requireExtendedMasterSecret = True

        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_MAC(self):
        hs = HandshakeSettings()
        hs.macNames = ['sha1', 'whirpool']

        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_KEX(self):
        hs = HandshakeSettings()
        hs.keyExchangeNames = ['rsa', 'ecdhe_rsa', 'gost']

        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_signature_algorithm(self):
        hs = HandshakeSettings()
        hs.rsaSigHashes += ['md2']
        with self.assertRaises(ValueError):
            hs.validate()

    def test_no_signature_hashes_set_with_TLS1_2(self):
        hs = HandshakeSettings()
        hs.rsaSigHashes = []
        hs.dsaSigHashes = []
        hs.ecdsaSigHashes = []
        hs.more_sig_schemes = []
        with self.assertRaises(ValueError):
            hs.validate()

    def test_no_signature_hashes_set_with_TLS1_1(self):
        hs = HandshakeSettings()
        hs.rsaSigHashes = []
        hs.dsaSigHashes = []
        hs.ecdsaSigHashes = []
        hs.maxVersion = (3, 2)
        self.assertIsNotNone(hs.validate())

    def test_invalid_signature_ecdsa_algorithm(self):
        hs = HandshakeSettings()
        hs.ecdsaSigHashes += ['md5']
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_curve_name(self):
        hs = HandshakeSettings()
        hs.eccCurves = ['P-256']
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_additional_signature(self):
        hs = HandshakeSettings()
        hs.more_sig_schemes = ["rsa_pkcs1_sha1"]
        with self.assertRaises(ValueError):
            hs.validate()

    def test_usePaddingExtension(self):
        hs = HandshakeSettings()
        self.assertTrue(hs.usePaddingExtension)

    def test_invalid_usePaddingExtension(self):
        hs = HandshakeSettings()
        hs.usePaddingExtension = -1
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_dhParams(self):
        hs = HandshakeSettings()
        hs.dhParams = (2, 'bd')
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_dhGroups(self):
        hs = HandshakeSettings()
        hs.dhGroups = ["ffdhe2048", "ffdhe1024"]
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_rsaScheme(self):
        hs = HandshakeSettings()
        hs.rsaSchemes += ["rsassa-pkcs1-1_5"]
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_defaultCurve_name(self):
        hs = HandshakeSettings()
        hs.defaultCurve = "ffdhe2048"
        with self.assertRaises(ValueError):
            hs.validate()

    def test_invalid_keyShares_name(self):
        hs = HandshakeSettings()
        hs.keyShares = ["ffdhe1024"]
        with self.assertRaises(ValueError):
            hs.validate()

    def test_not_matching_keyShares(self):
        hs = HandshakeSettings()
        hs.keyShares = ["x25519"]
        hs.eccCurves = ["x448"]
        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("x25519", str(e.exception))

    def test_not_matching_ffdhe_keyShares(self):
        hs = HandshakeSettings()
        hs.keyShares = ["ffdhe2048", "x25519"]
        hs.dhGroups = ["ffdhe4096"]
        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("ffdhe2048", str(e.exception))

    def test_versions_and_maxVersion_mismatch(self):
        hs = HandshakeSettings()
        hs.maxVersion = (3, 3)
        hs = hs.validate()

        self.assertNotIn((3, 4), hs.versions)
        self.assertNotIn((0x7f, 21), hs.versions)

    def test_pskConfigs(self):
        hs = HandshakeSettings()
        hs.pskConfigs = [(b'test', b'sicritz', 'sha384')]

        hs = hs.validate()

        self.assertEqual(hs.pskConfigs, [(b'test', b'sicritz', 'sha384')])

    def test_pskConfigs_invalid_tuple(self):
        hs = HandshakeSettings()
        hs.pskConfigs = [(b'test', b'sicrits'), tuple([b'invalid'])]

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("pskConfigs", str(e.exception))

    def test_pskConfig_invalid_hash(self):
        hs = HandshakeSettings()
        hs.pskConfigs = [(b'test', b'sicrits', 'wrong-hash')]

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("wrong-hash", str(e.exception))

    def test_ticketCipher_invalid(self):
        hs = HandshakeSettings()
        hs.ticketCipher = "aes-128-cbc"

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("Invalid cipher", str(e.exception))

    def test_ticketKeys_wrong_size(self):
        hs = HandshakeSettings()
        hs.ticketKeys = [bytearray(8)]

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("encryption keys", str(e.exception))

    def test_ticketLifetime_wrong(self):
        hs = HandshakeSettings()
        hs.ticketLifetime = 2**32

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("Ticket lifetime", str(e.exception))

    def test_invalid_psk_mode(self):
        hs = HandshakeSettings()
        hs.psk_modes = ["psk_pqe_ke"]

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("psk_pqe_ke", str(e.exception))

    def test_invalid_max_early_data(self):
        hs = HandshakeSettings()
        hs.max_early_data = -1

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("max_early_data", str(e.exception))

    def test_invalid_use_heartbeat_extension(self):
        hs = HandshakeSettings()
        hs.use_heartbeat_extension = None

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("use_heartbeat_extension", str(e.exception))

    def test_invalid_heartbeat_extension_combination(self):
        hs = HandshakeSettings()
        def heartbeatResponseCallback(message):
            return message
        hs.heartbeat_response_callback = heartbeatResponseCallback
        hs.use_heartbeat_extension = False

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("heartbeat_response_callback", str(e.exception))

    def test_too_small_record_size_limit(self):
        hs = HandshakeSettings()
        hs.record_size_limit = 63

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("record_size_limit", str(e.exception))

    def test_too_big_record_size_limit(self):
        hs = HandshakeSettings()
        hs.record_size_limit = 2**14+2

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("record_size_limit", str(e.exception))

    def test_none_as_record_size_limit(self):
        hs = HandshakeSettings()
        self.assertIsNotNone(hs.record_size_limit)

        hs.record_size_limit = None

        hs = hs.validate()

        self.assertIsNone(hs.record_size_limit)

    def test_ticket_count_zero(self):
        hs = HandshakeSettings()
        hs.ticket_count = 0

        hs = hs.validate()

        self.assertIsNotNone(hs.ticket_count, 0)

    def test_ticket_count_200(self):
        hs = HandshakeSettings()
        hs.ticket_count = 200

        hs = hs.validate()

        self.assertIsNotNone(hs.ticket_count, 200)

    def test_ticket_count_negative(self):
        hs = HandshakeSettings()
        hs.ticket_count = -1

        with self.assertRaises(ValueError) as e:
            hs.validate()

        self.assertIn("new session tickets", str(e.exception))


class TestKeypair(unittest.TestCase):
    def test___init___(self):
        k_p = Keypair()

        self.assertIsInstance(k_p, Keypair)
        self.assertIsNone(k_p.key)
        self.assertIsInstance(k_p.certificates, tuple)

    def test_validate_with_missing_keys(self):
        k_p = Keypair()

        with self.assertRaises(ValueError):
            k_p.validate()

    def test_validate_with_missing_certificates(self):
        k_p = Keypair()
        k_p.key = mock.MagicMock()

        with self.assertRaises(ValueError):
            k_p.validate()


class TestVirtualHost(unittest.TestCase):
    def test___init__(self):
        v_h = VirtualHost()

        self.assertIsInstance(v_h, VirtualHost)
        self.assertEqual(v_h.keys, [])
        self.assertEqual(v_h.hostnames, set())
        self.assertEqual(v_h.trust_anchors, [])
        self.assertEqual(v_h.app_protocols, [])

    def test_matches_hostname_with_non_matching_name(self):
        v_h = VirtualHost()
        v_h.hostnames = set([b'example.com'])

        self.assertFalse(v_h.matches_hostname(b'example.org'))

    def test_matches_hostname_with_matching_name(self):
        v_h = VirtualHost()
        v_h.hostnames = set([b'example.com'])

        self.assertTrue(v_h.matches_hostname(b'example.com'))

    def test_validate_without_keys(self):
        v_h = VirtualHost()

        with self.assertRaises(ValueError):
            v_h.validate()

    def test_validate_with_keys(self):
        v_h = VirtualHost()
        v_h.keys = [mock.MagicMock()]

        v_h.validate()

        v_h.keys[0].validate.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
