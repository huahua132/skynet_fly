# Copyright (c) 2014, Karel Srot
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest
from tlslite.handshakehelpers import HandshakeHelpers
from tlslite.messages import ClientHello, NewSessionTicket
from tlslite.extensions import SNIExtension, PreSharedKeyExtension, \
        PskIdentity
from tlslite.handshakehashes import HandshakeHashes
from tlslite.errors import TLSIllegalParameterException

class TestHandshakeHelpers(unittest.TestCase):
    def test_alignClientHelloPadding_length_less_than_256_bytes(self):
        clientHello = ClientHello()
        clientHello.create((3,0), bytearray(32), bytearray(0), [])

        clientHelloLength = len(clientHello.write())
        self.assertTrue(clientHelloLength - 4 < 256)

        HandshakeHelpers.alignClientHelloPadding(clientHello)

        # clientHello should not be changed due to small length
        self.assertEqual(clientHelloLength, len(clientHello.write()))

    def test_alignClientHelloPadding_length_256_bytes(self):
        clientHello = ClientHello()
        clientHello.create((3,0), bytearray(32), bytearray(0), [])
        clientHello.extensions = []

        ext = SNIExtension()
        ext.create(hostNames=[
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeee'),
        ])
        clientHello.extensions.append(ext)
        clientHelloLength = len(clientHello.write())
        # clientHello length (excluding 4B header) should equal to 256
        self.assertEqual(256, clientHelloLength - 4)

        HandshakeHelpers.alignClientHelloPadding(clientHello)

        # clientHello length (excluding 4B header) should equal to 512
        data = clientHello.write()
        self.assertEqual(512, len(data) - 4)
        # previously created data should be extended with the padding extension
        # starting with the padding extension type \x00\x15 (21)
        self.assertEqual(bytearray(b'\x00\x15'), data[clientHelloLength:clientHelloLength+2])

    def test_alignClientHelloPadding_length_of_508_bytes(self):
        clientHello = ClientHello()
        clientHello.create((3,0), bytearray(32), bytearray(0), [])
        clientHello.extensions = []

        ext = SNIExtension()
        ext.create(hostNames=[
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccdddd'),
        ])
        clientHello.extensions.append(ext)
        clientHelloLength = len(clientHello.write())
        self.assertEqual(508, clientHelloLength - 4)

        HandshakeHelpers.alignClientHelloPadding(clientHello)

        # clientHello length should equal to 512, ignoring handshake
        # protocol header (4B)
        data = clientHello.write()
        self.assertEqual(512, len(data) - 4)
        # padding extension should have zero byte size
        self.assertEqual(bytearray(b'\x00\x15\x00\x00'), data[clientHelloLength:])

    def test_alignClientHelloPadding_length_of_511_bytes(self):
        clientHello = ClientHello()
        clientHello.create((3,0), bytearray(32), bytearray(0), [])
        clientHello.extensions = []

        ext = SNIExtension()
        ext.create(hostNames=[
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddd'),
        ])
        clientHello.extensions.append(ext)
        clientHelloLength = len(clientHello.write())
        self.assertEqual(511, clientHelloLength - 4)

        HandshakeHelpers.alignClientHelloPadding(clientHello)

        # clientHello length should equal to 515, ignoring handshake
        # protocol header (4B)
        data = clientHello.write()
        self.assertEqual(515, len(data) - 4)
        # padding extension should have zero byte size
        self.assertEqual(bytearray(b'\x00\x15\x00\x00'), data[clientHelloLength:])


    def test_alignClientHelloPadding_length_of_512_bytes(self):
        clientHello = ClientHello()
        clientHello.create((3,0), bytearray(32), bytearray(0), [])
        clientHello.extensions = []

        ext = SNIExtension()
        ext.create(hostNames=[
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee'),
            bytearray(b'aaaaaaaaaabbbbbbbbbbccccccccccdddddddd'),
        ])
        clientHello.extensions.append(ext)
        clientHelloLength = len(clientHello.write())
        self.assertEqual(512, clientHelloLength - 4)

        HandshakeHelpers.alignClientHelloPadding(clientHello)

        # clientHello should not be changed due to sufficient length (>=512)
        self.assertEqual(clientHelloLength, len(clientHello.write()))

    def test_alignClientHelloPadding_extension_list_initialization(self):
        clientHello = ClientHello()
        clientHello.create((3,0), bytearray(32), bytearray(0), range(0, 129))

        clientHelloLength = len(clientHello.write())
        self.assertTrue(512 > clientHelloLength - 4 > 255)

        HandshakeHelpers.alignClientHelloPadding(clientHello)

        # verify that the extension list has been added to clientHello
        self.assertTrue(type(clientHello.extensions) is list)
        # clientHello length should equal to 512, ignoring handshake
        # protocol header (4B)
        data = clientHello.write()
        self.assertEqual(512, len(data) - 4)
        # padding extension should have been added after 2 extra bytes
        # added due to an extension list
        self.assertEqual(bytearray(b'\x00\x15'), data[clientHelloLength+2:clientHelloLength+4])

    def test_update_binders_wrong_last_ext(self):
        """
        PSK binders mandate that the PSK extension be the very last extension
        in client hello (as it's necessary to truncate the body of the hello
        up to the PSK extension and calculate hash over it)
        check if the updater will abort if the passed in message has
        PSK extension that is not last
        """
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(32)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        sni_ext = SNIExtension().create(b'example.com')

        clientHello.extensions = [psk_ext, sni_ext]

        hh = HandshakeHashes()

        pskConfigs = [(b'test', b'\x00\x12\x13')]

        with self.assertRaises(ValueError) as e:
            HandshakeHelpers.update_binders(clientHello, hh, pskConfigs)

        self.assertIn('Last extension', str(e.exception))

    def test_update_binders_with_wrong_config(self):
        """
        Updater requires all binders to be have associated configurations
        otherwise it wouldb't be able to calculate a new binder value
        in this case, the identity in ClientHello is "test" while in
        configurations it's "example"
        """
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(32)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        hh = HandshakeHashes()

        pskConfigs = [(b'example', b'\x00\x12\x13')]

        with self.assertRaises(ValueError) as e:
            HandshakeHelpers.update_binders(clientHello, hh, pskConfigs)

        self.assertIn('psk_configs', str(e.exception))

    def test_update_binders_default_prf(self):
        """
        Verify that configurations that don't specify the associated hash
        explicitly still work correctly (as the TLS 1.3 standard mandates
        that SHA-256 is used by default)
        """
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(32)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        hh = HandshakeHashes()

        pskConfigs = [(b'test', b'\x00\x12\x13')]

        HandshakeHelpers.update_binders(clientHello, hh, pskConfigs)

        self.assertIsInstance(clientHello.extensions[-1],
                              PreSharedKeyExtension)
        ch_ext = clientHello.extensions[-1]
        self.assertEqual(ch_ext.identities, identities)
        self.assertEqual(ch_ext.binders,
                         [bytearray(b'wOl\xbe\x9b\xca\xa4\xf3tS\x08M\ta\xa2t'
                                    b'\xa5lYF\xb7\x01F{M\xab\x85R\xa3'
                                    b'\xf3\x11^')])

    def test_update_binders_sha256_prf(self):
        """Check if we can calculate a binder that uses SHA-256 PRF."""
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(32)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        hh = HandshakeHashes()

        pskConfigs = [(b'test', b'\x00\x12\x13', 'sha256')]

        HandshakeHelpers.update_binders(clientHello, hh, pskConfigs)

        self.assertIsInstance(clientHello.extensions[-1],
                              PreSharedKeyExtension)
        ch_ext = clientHello.extensions[-1]
        self.assertEqual(ch_ext.identities, identities)
        self.assertEqual(ch_ext.binders,
                         [bytearray(b'wOl\xbe\x9b\xca\xa4\xf3tS\x08M\ta\xa2t'
                                    b'\xa5lYF\xb7\x01F{M\xab\x85R\xa3'
                                    b'\xf3\x11^')])

    def test_update_binders_sha384_prf(self):
        """Check if we can calculate a binder that uses SHA-384 PRF."""
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(48)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        hh = HandshakeHashes()

        pskConfigs = [(b'test', b'\x00\x12\x13', 'sha384')]

        HandshakeHelpers.update_binders(clientHello, hh, pskConfigs)

        self.assertIsInstance(clientHello.extensions[-1],
                              PreSharedKeyExtension)
        ch_ext = clientHello.extensions[-1]
        self.assertEqual(ch_ext.identities, identities)
        self.assertEqual(ch_ext.binders,
                         [bytearray(b'\x8d\x92\xd2\xb7+D&\xd7\x0e>x\x1a\xc5i+'
                                    b'M\x0e\xd2\xfe\xd6\x11\x07\n\x0c\xdc\xcf'
                                    b'\xee\xf43\x8e\x9b@z\x00\xbcE\xff\x15%'
                                    b'\xdc\xee\xb4\x1c\x8f\\\x03Z\xc5')])

    def test_update_binders_with_ticket(self):
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'\x00ticket\x00ident'),
                                           123)]
        binders = [bytearray(48)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        ticket = NewSessionTicket().create(3600,  # ticket lifetime
                                           123,   # age_add
                                           bytearray(b'\xc0' * 48),  # nonce
                                           bytearray(b'\x00ticket\x00ident'),
                                           [])
        hh = HandshakeHashes()
        resum_master_secret = bytearray(b'\x01' * 48)

        HandshakeHelpers.update_binders(clientHello, hh, [], [ticket],
                                        resum_master_secret)

        self.assertIsInstance(clientHello.extensions[-1],
                              PreSharedKeyExtension)

        ch_ext = clientHello.extensions[-1]
        self.assertEqual(ch_ext.identities, identities)
        self.assertEqual(ch_ext.binders,
                         [bytearray(b'<\x03\xcd\xd5\xce\xaeo\x8d\xc6\x8c\xe3'
                                    b'\xe3\xbc\xa2h\xdcm0+\xa7\xbe\xf7\x9ca-'
                                    b'\xcc\x0c\xdb\xb2ZtE\x1e:\xe2\xc4\xb8'
                                    b'\x1bd\x10wN\x8a\xb0\x90\x7f\xb1F')])

    def test_update_binders_with_missing_secret(self):
        clientHello = ClientHello()
        psk = PreSharedKeyExtension()
        clientHello.extensions = [psk]
        hh = HandshakeHashes()

        with self.assertRaises(ValueError):
            HandshakeHelpers.update_binders(clientHello, hh, [], [None])

    def test_verify_binder_with_wrong_extension(self):
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(32)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        sni_ext = SNIExtension().create(b'example.com')

        clientHello.extensions = [psk_ext, sni_ext]

        hh = HandshakeHashes()

        secret = b'\x00\x12\x13'

        with self.assertRaises(TLSIllegalParameterException) as e:
            HandshakeHelpers.verify_binder(clientHello, hh, 0, secret,
                                           'sha256')

        self.assertIn('Last extension', str(e.exception))

    def test_verify_binder(self):
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(b'\x8d\x92\xd2\xb7+D&\xd7\x0e>x\x1a\xc5i+'
                             b'M\x0e\xd2\xfe\xd6\x11\x07\n\x0c\xdc\xcf'
                             b'\xee\xf43\x8e\x9b@z\x00\xbcE\xff\x15%'
                             b'\xdc\xee\xb4\x1c\x8f\\\x03Z\xc5')]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        hh = HandshakeHashes()

        secret = b'\x00\x12\x13'

        ret = HandshakeHelpers.verify_binder(clientHello, hh, 0, secret,
                                             'sha384')
        self.assertIs(ret, True)

    def test_verify_binder_with_wrong_binder(self):
        clientHello = ClientHello()
        clientHello.create((3, 3), bytearray(32), bytearray(0), [0])
        identities = [PskIdentity().create(bytearray(b'test'), 0)]
        binders = [bytearray(48)]
        psk_ext = PreSharedKeyExtension().create(identities, binders)
        clientHello.extensions = [psk_ext]

        hh = HandshakeHashes()

        secret = b'\x00\x12\x13'

        with self.assertRaises(TLSIllegalParameterException) as e:
            HandshakeHelpers.verify_binder(clientHello, hh, 0, secret,
                                           'sha384')

        self.assertIn('not verify', str(e.exception))


if __name__ == '__main__':
    unittest.main()
