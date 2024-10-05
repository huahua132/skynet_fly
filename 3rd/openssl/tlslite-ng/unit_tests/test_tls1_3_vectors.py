# Copyright (c) 2017, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

try:
    import unittest2 as unittest
except ImportError:
    import unittest

import sys

from tlslite.recordlayer import RecordLayer
from tlslite.messages import ServerHello, ClientHello, Alert, RecordHeader3, \
        Finished, EncryptedExtensions
from tlslite.constants import CipherSuite, AlertDescription, ContentType, \
        ExtensionType, GroupName, ECPointFormat, HashAlgorithm, \
        SignatureAlgorithm, SignatureScheme, HandshakeType, TLS_1_3_DRAFT
from tlslite.tlsconnection import TLSConnection
from tlslite.errors import TLSLocalAlert, TLSRemoteAlert
from tlslite.x509 import X509
from tlslite.x509certchain import X509CertChain
from tlslite.utils.keyfactory import parsePEMKey
from tlslite.handshakesettings import HandshakeSettings
from tlslite.session import Session
from tlslite.utils.codec import Parser
from tlslite.extensions import TLSExtension, SNIExtension, \
        SupportedGroupsExtension, ECPointFormatsExtension, \
        ClientKeyShareExtension, KeyShareEntry, SupportedVersionsExtension, \
        SignatureAlgorithmsExtension, RecordSizeLimitExtension
from tlslite.utils.x25519 import x25519
from tlslite.utils.cryptomath import secureHMAC, HKDF_expand_label, \
        derive_secret
from tlslite.handshakehashes import HandshakeHashes
from unit_tests.mocksock import MockSocket
import binascii


def clean(s):
    return bytearray(binascii.unhexlify(''.join(c for c in s if c.isalnum())))


client_key_public = clean("""
        99 38 1d e5 60 e4 bd 43 d2 3d 8e 43 5a 7d
        ba fe b3 c0 6e 51 c1 3c ae 4d 54 13 69 1e 52 9a af 2c
        """)

client_key_private = clean("""
        49 af 42 ba 7f 79 94 85 2d 71 3e f2 78
        4b cb ca a7 91 1d e2 6a dc 56 42 cb 63 45 40 e7 ea 50 05
        """)

client_hello_plaintext = clean("""
        01 00 00 c0 03 03 cb 34 ec b1 e7 81 63
        ba 1c 38 c6 da cb 19 6a 6d ff a2 1a 8d 99 12 ec 18 a2 ef 62 83
        02 4d ec e7 00 00 06 13 01 13 03 13 02 01 00 00 91 00 00 00 0b
        00 09 00 00 06 73 65 72 76 65 72 ff 01 00 01 00 00 0a 00 14 00
        12 00 1d 00 17 00 18 00 19 01 00 01 01 01 02 01 03 01 04 00 23
        00 00 00 33 00 26 00 24 00 1d 00 20 99 38 1d e5 60 e4 bd 43 d2
        3d 8e 43 5a 7d ba fe b3 c0 6e 51 c1 3c ae 4d 54 13 69 1e 52 9a
        af 2c 00 2b 00 03 02 03 04 00 0d 00 20 00 1e 04 03 05 03 06 03
        02 03 08 04 08 05 08 06 04 01 05 01 06 01 02 01 04 02 05 02 06
        02 02 02 00 2d 00 02 01 01 00 1c 00 02 40 01
        """)

client_hello_ciphertext = clean("""
        16 03 01 00 c4 01 00 00 c0 03 03 cb
        34 ec b1 e7 81 63 ba 1c 38 c6 da cb 19 6a 6d ff a2 1a 8d 99 12
        ec 18 a2 ef 62 83 02 4d ec e7 00 00 06 13 01 13 03 13 02 01 00
        00 91 00 00 00 0b 00 09 00 00 06 73 65 72 76 65 72 ff 01 00 01
        00 00 0a 00 14 00 12 00 1d 00 17 00 18 00 19 01 00 01 01 01 02
        01 03 01 04 00 23 00 00 00 33 00 26 00 24 00 1d 00 20 99 38 1d
        e5 60 e4 bd 43 d2 3d 8e 43 5a 7d ba fe b3 c0 6e 51 c1 3c ae 4d
        54 13 69 1e 52 9a af 2c 00 2b 00 03 02 03 04 00 0d 00 20 00 1e
        04 03 05 03 06 03 02 03 08 04 08 05 08 06 04 01 05 01 06 01 02
        01 04 02 05 02 06 02 02 02 00 2d 00 02 01 01 00 1c 00 02 40 01
        """)

server_hello_payload = clean("""
        02 00 00 56 03 03 a6 af 06 a4 12 18 60 dc 5e
        6e 60 24 9c d3 4c 95 93 0c 8a c5 cb 14 34 da c1 55 77 2e d3 e2
        69 28 00 13 01 00 00 2e 00 33 00 24 00 1d 00 20 c9 82 88 76 11
        20 95 fe 66 76 2b db f7 c6 72 e1 56 d6 cc 25 3b 83 3d f1 dd 69
        b1 b0 4e 75 1f 0f 00 2b 00 02 03 04
        """)

server_hello_ciphertext = clean("""
        16 03 03 00 5a 02 00 00 56 03 03 a6
        af 06 a4 12 18 60 dc 5e 6e 60 24 9c d3 4c 95 93 0c 8a c5 cb 14
        34 da c1 55 77 2e d3 e2 69 28 00 13 01 00 00 2e 00 33 00 24 00
        1d 00 20 c9 82 88 76 11 20 95 fe 66 76 2b db f7 c6 72 e1 56 d6
        cc 25 3b 83 3d f1 dd 69 b1 b0 4e 75 1f 0f 00 2b 00 02 03 04
        """)

server_certificate_message = clean("""
        0b 00 01 b9 00 00 01 b5 00 01 b0 30 82
        01 ac 30 82 01 15 a0 03 02 01 02 02 01 02 30 0d 06 09 2a 86 48
        86 f7 0d 01 01 0b 05 00 30 0e 31 0c 30 0a 06 03 55 04 03 13 03
        72 73 61 30 1e 17 0d 31 36 30 37 33 30 30 31 32 33 35 39 5a 17
        0d 32 36 30 37 33 30 30 31 32 33 35 39 5a 30 0e 31 0c 30 0a 06
        03 55 04 03 13 03 72 73 61 30 81 9f 30 0d 06 09 2a 86 48 86 f7
        0d 01 01 01 05 00 03 81 8d 00 30 81 89 02 81 81 00 b4 bb 49 8f
        82 79 30 3d 98 08 36 39 9b 36 c6 98 8c 0c 68 de 55 e1 bd b8 26
        d3 90 1a 24 61 ea fd 2d e4 9a 91 d0 15 ab bc 9a 95 13 7a ce 6c
        1a f1 9e aa 6a f9 8c 7c ed 43 12 09 98 e1 87 a8 0e e0 cc b0 52
        4b 1b 01 8c 3e 0b 63 26 4d 44 9a 6d 38 e2 2a 5f da 43 08 46 74
        80 30 53 0e f0 46 1c 8c a9 d9 ef bf ae 8e a6 d1 d0 3e 2b d1 93
        ef f0 ab 9a 80 02 c4 74 28 a6 d3 5a 8d 88 d7 9f 7f 1e 3f 02 03
        01 00 01 a3 1a 30 18 30 09 06 03 55 1d 13 04 02 30 00 30 0b 06
        03 55 1d 0f 04 04 03 02 05 a0 30 0d 06 09 2a 86 48 86 f7 0d 01
        01 0b 05 00 03 81 81 00 85 aa d2 a0 e5 b9 27 6b 90 8c 65 f7 3a
        72 67 17 06 18 a5 4c 5f 8a 7b 33 7d 2d f7 a5 94 36 54 17 f2 ea
        e8 f8 a5 8c 8f 81 72 f9 31 9c f3 6b 7f d6 c5 5b 80 f2 1a 03 01
        51 56 72 60 96 fd 33 5e 5e 67 f2 db f1 02 70 2e 60 8c ca e6 be
        c1 fc 63 a4 2a 99 be 5c 3e b7 10 7c 3c 54 e9 b9 eb 2b d5 20 3b
        1c 3b 84 e0 a8 b2 f7 59 40 9b a3 ea c9 d9 1d 40 2d cc 0c c8 f8
        96 12 29 ac 91 87 b4 2b 4d e1 00 00
        """)

server_certificateverify_message = clean("""
        0f 00 00 84 08 04 00 80 5a 74 7c
        5d 88 fa 9b d2 e5 5a b0 85 a6 10 15 b7 21 1f 82 4c d4 84 14 5a
        b3 ff 52 f1 fd a8 47 7b 0b 7a bc 90 db 78 e2 d3 3a 5c 14 1a 07
        86 53 fa 6b ef 78 0c 5e a2 48 ee aa a7 85 c4 f3 94 ca b6 d3 0b
        be 8d 48 59 ee 51 1f 60 29 57 b1 54 11 ac 02 76 71 45 9e 46 44
        5c 9e a5 8c 18 1e 81 8e 95 b8 c3 fb 0b f3 27 84 09 d3 be 15 2a
        3d a5 04 3e 06 3d da 65 cd f5 ae a2 0d 53 df ac d4 2f 74 f3
        """)

server_encrypted_extensions = clean("""
        08 00 00 24 00 22 00 0a 00 14 00
        12 00 1d 00 17 00 18 00 19 01 00 01 01 01 02 01 03 01 04 00 1c
        00 02 40 01 00 00 00 00
        """)


class TestSimple1RTTHandshakeAsClient(unittest.TestCase):
    def test(self):

        sock = MockSocket(server_hello_ciphertext)

        record_layer = RecordLayer(sock)

        ext = [SNIExtension().create(bytearray(b'server')),
               TLSExtension(extType=ExtensionType.renegotiation_info)
               .create(bytearray(b'\x00')),
               SupportedGroupsExtension().create([GroupName.x25519,
                                                  GroupName.secp256r1,
                                                  GroupName.secp384r1,
                                                  GroupName.secp521r1,
                                                  GroupName.ffdhe2048,
                                                  GroupName.ffdhe3072,
                                                  GroupName.ffdhe4096,
                                                  GroupName.ffdhe6144,
                                                  GroupName.ffdhe8192]),
               TLSExtension(extType=35),
               ClientKeyShareExtension().create([KeyShareEntry().create(GroupName.x25519,
                                                client_key_public,
                                                client_key_private)]),
               SupportedVersionsExtension().create([(3, 4)]),
               SignatureAlgorithmsExtension().create([SignatureScheme.ecdsa_secp256r1_sha256,
                                                      SignatureScheme.ecdsa_secp384r1_sha384,
                                                      SignatureScheme.ecdsa_secp521r1_sha512,
                                                      (HashAlgorithm.sha1,
                                                       SignatureAlgorithm.ecdsa),
                                                      SignatureScheme.rsa_pss_rsae_sha256,
                                                      SignatureScheme.rsa_pss_rsae_sha384,
                                                      SignatureScheme.rsa_pss_rsae_sha512,
                                                      SignatureScheme.rsa_pkcs1_sha256,
                                                      SignatureScheme.rsa_pkcs1_sha384,
                                                      SignatureScheme.rsa_pkcs1_sha512,
                                                      SignatureScheme.rsa_pkcs1_sha1,
                                                      (HashAlgorithm.sha256,
                                                       SignatureAlgorithm.dsa),
                                                      (HashAlgorithm.sha384,
                                                       SignatureAlgorithm.dsa),
                                                      (HashAlgorithm.sha512,
                                                       SignatureAlgorithm.dsa),
                                                      (HashAlgorithm.sha1,
                                                       SignatureAlgorithm.dsa)]),
                TLSExtension(extType=45).create(bytearray(b'\x01\x01')),
                RecordSizeLimitExtension().create(16385)
               ]
        client_hello = ClientHello()
        client_hello.create((3, 3),
                            bytearray(b'\xcb4\xec\xb1\xe7\x81c'
                                      b'\xba\x1c8\xc6\xda\xcb'
                                      b'\x19jm\xff\xa2\x1a\x8d'
                                      b'\x99\x12\xec\x18\xa2'
                                      b'\xefb\x83\x02M\xec\xe7'),
                            bytearray(b''),
                            [CipherSuite.TLS_AES_128_GCM_SHA256,
                             CipherSuite.TLS_CHACHA20_POLY1305_SHA256,
                             CipherSuite.TLS_AES_256_GCM_SHA384],
                            extensions=ext)

        self.assertEqual(client_hello.write(), client_hello_ciphertext[5:])

        for result in record_layer.recvRecord():
            # check if non-blocking
            self.assertNotIn(result, (0, 1))
            break

        header, parser = result
        hs_type = parser.get(1)
        self.assertEqual(hs_type, HandshakeType.server_hello)
        server_hello = ServerHello().parse(parser)

        self.assertEqual(server_hello.server_version, (3, 3))
        self.assertEqual(server_hello.cipher_suite, CipherSuite.TLS_AES_128_GCM_SHA256)

        server_key_share = server_hello.getExtension(ExtensionType.key_share)
        server_key_share = server_key_share.server_share

        self.assertEqual(server_key_share.group, GroupName.x25519)

        # for TLS_AES_128_GCM_SHA256:
        prf_name = 'sha256'
        prf_size = 256 // 8
        secret = bytearray(prf_size)
        psk = bytearray(prf_size)

        # early secret
        secret = secureHMAC(secret, psk, prf_name)

        self.assertEqual(secret,
                         clean("""
                         33 ad 0a 1c 60 7e c0 3b 09 e6 cd 98 93 68 0c
                         e2 10 ad f3 00 aa 1f 26 60 e1 b2 2e 10 f1 70 f9 2a
                         """))

        # derive secret for handshake
        secret = derive_secret(secret, b"derived", None, prf_name)

        self.assertEqual(secret,
                         clean("""
                         6f 26 15 a1 08 c7 02 c5 67 8f 54 fc 9d ba
                         b6 97 16 c0 76 18 9c 48 25 0c eb ea c3 57 6c 36 11 ba
                         """))

        # extract secret "handshake"
        Z = x25519(client_key_private, server_key_share.key_exchange)

        self.assertEqual(Z,
                         clean("""
                         8b d4 05 4f b5 5b 9d 63 fd fb ac f9 f0 4b 9f 0d
                         35 e6 d6 3f 53 75 63 ef d4 62 72 90 0f 89 49 2d
                         """))

        secret = secureHMAC(secret, Z, prf_name)

        self.assertEqual(secret,
                         clean("""
                         1d c8 26 e9 36 06 aa 6f dc 0a ad c1 2f 74 1b
                         01 04 6a a6 b9 9f 69 1e d2 21 a9 f0 ca 04 3f be ac
                         """))

        handshake_hashes = HandshakeHashes()
        handshake_hashes.update(client_hello_plaintext)
        handshake_hashes.update(server_hello_payload)

        # derive "tls13 c hs traffic"
        c_hs_traffic = derive_secret(secret,
                                     bytearray(b'c hs traffic'),
                                     handshake_hashes,
                                     prf_name)
        self.assertEqual(c_hs_traffic,
                         clean("""
                         b3 ed db 12 6e 06 7f 35 a7 80 b3 ab f4 5e
                         2d 8f 3b 1a 95 07 38 f5 2e 96 00 74 6a 0e 27 a5 5a 21
                         """))
        s_hs_traffic = derive_secret(secret,
                                     bytearray(b's hs traffic'),
                                     handshake_hashes,
                                     prf_name)
        self.assertEqual(s_hs_traffic,
                         clean("""
                         b6 7b 7d 69 0c c1 6c 4e 75 e5 42 13 cb 2d
                         37 b4 e9 c9 12 bc de d9 10 5d 42 be fd 59 d3 91 ad 38
                         """))

        # derive master secret
        secret = derive_secret(secret, b"derived", None, prf_name)

        self.assertEqual(secret,
                         clean("""
                         43 de 77 e0 c7 77 13 85 9a 94 4d b9 db 25
                         90 b5 31 90 a6 5b 3e e2 e4 f1 2d d7 a0 bb 7c e2 54 b4
                         """))

        # extract secret "master"
        secret = secureHMAC(secret, bytearray(prf_size), prf_name)

        self.assertEqual(secret,
                         clean("""
                         18 df 06 84 3d 13 a0 8b f2 a4 49 84 4c 5f 8a
                         47 80 01 bc 4d 4c 62 79 84 d5 a4 1d a8 d0 40 29 19
                         """))

        # derive write keys for handshake data
        server_hs_write_trafic_key = HKDF_expand_label(s_hs_traffic, b"key",
                                                       b"", 16, prf_name)

        self.assertEqual(server_hs_write_trafic_key,
                         clean("""
                         3f ce 51 60 09 c2 17 27 d0 f2 e4 e8 6e
                         e4 03 bc
                         """))

        server_hs_write_trafic_iv = HKDF_expand_label(s_hs_traffic, b"iv",
                                                       b"", 12, prf_name)

        self.assertEqual(server_hs_write_trafic_iv,
                         clean("""
                         5d 31 3e b2 67 12 76 ee 13 00 0b 30
                         """))

        # derive key for Finished message
        server_finished_key = HKDF_expand_label(s_hs_traffic, b"finished",
                                                       b"", prf_size, prf_name)
        self.assertEqual(server_finished_key,
                         clean("""
                         00 8d 3b 66 f8 16 ea 55 9f 96 b5 37 e8 85
                         c3 1f c0 68 bf 49 2c 65 2f 01 f2 88 a1 d8 cd c1 9f c8
                         """))

        # Update the handshake transcript
        handshake_hashes.update(server_encrypted_extensions)
        handshake_hashes.update(server_certificate_message)
        handshake_hashes.update(server_certificateverify_message)
        hs_transcript = handshake_hashes.digest(prf_name)

        server_finished = secureHMAC(server_finished_key, hs_transcript, prf_name)

        self.assertEqual(server_finished,
                         clean("""
                         9b 9b 14 1d 90 63 37 fb d2 cb dc e7 1d f4
                         de da 4a b4 2c 30 95 72 cb 7f ff ee 54 54 b7 8f 07 18
                         """))

        server_finished_message = Finished((3, 4)).create(server_finished)
        server_finished_payload = server_finished_message.write()

        # update handshake transcript to include Finished payload
        handshake_hashes.update(server_finished_payload)

        # derive keys for client application traffic
        c_ap_traffic = derive_secret(secret, b"c ap traffic", handshake_hashes, prf_name)

        self.assertEqual(c_ap_traffic,
                         clean("""
                         9e 40 64 6c e7 9a 7f 9d c0 5a f8 88 9b ce
                         65 52 87 5a fa 0b 06 df 00 87 f7 92 eb b7 c1 75 04 a5
                         """))

        # derive keys for server application traffic
        s_ap_traffic = derive_secret(secret, b"s ap traffic", handshake_hashes, prf_name)

        self.assertEqual(s_ap_traffic,
                         clean("""
                         a1 1a f9 f0 55 31 f8 56 ad 47 11 6b 45 a9
                         50 32 82 04 b4 f4 4b fb 6b 3a 4b 4f 1f 3f cb 63 16 43
                         """))

        # derive exporter master secret
        exp_master = derive_secret(secret, b"exp master", handshake_hashes, prf_name)

        self.assertEqual(exp_master,
                         clean("""
                         fe 22 f8 81 17 6e da 18 eb 8f 44 52 9e 67
                         92 c5 0c 9a 3f 89 45 2f 68 d8 ae 31 1b 43 09 d3 cf 50
                         """))

        # derive write traffic keys for app data
        server_write_traffic_key = HKDF_expand_label(s_ap_traffic, b"key",
                                                     b"", 16, prf_name)

        self.assertEqual(server_write_traffic_key,
                         clean("""
                         9f 02 28 3b 6c 9c 07 ef c2 6b b9 f2 ac
                         92 e3 56
                         """))

        server_write_traffic_iv = HKDF_expand_label(s_ap_traffic, b"iv",
                                                     b"", 12, prf_name)

        self.assertEqual(server_write_traffic_iv,
                         clean("""
                         cf 78 2b 88 dd 83 54 9a ad f1 e9 84
                         """))

        # derive read traffic keys for app data
        server_read_hs_key = HKDF_expand_label(c_hs_traffic, b"key",
                                                     b"", 16, prf_name)

        self.assertEqual(server_read_hs_key,
                         clean("""
                         db fa a6 93 d1 76 2c 5b 66 6a f5 d9 50
                         25 8d 01
                         """))

        server_read_hs_iv = HKDF_expand_label(c_hs_traffic, b"iv",
                                                     b"", 12, prf_name)

        self.assertEqual(server_read_hs_iv,
                         clean("""
                         5b d3 c7 1b 83 6e 0b 76 bb 73 26 5f
                         """))
