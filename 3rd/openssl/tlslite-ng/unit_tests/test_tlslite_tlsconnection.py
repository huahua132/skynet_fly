# Copyright (c) 2015, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

import socket
import threading

from tlslite.recordlayer import RecordLayer
from tlslite.messages import ServerHello, ClientHello, Alert, RecordHeader3
from tlslite.constants import CipherSuite, AlertDescription, ContentType, \
    GroupName, TLS_1_3_HRR
from tlslite.tlsconnection import TLSConnection
from tlslite.errors import TLSLocalAlert, TLSRemoteAlert
from tlslite.x509 import X509
from tlslite.x509certchain import X509CertChain
from tlslite.utils.keyfactory import parsePEMKey
from tlslite.handshakesettings import HandshakeSettings
from tlslite.session import Session
from tlslite.extensions import SrvSupportedVersionsExtension, \
    ServerKeyShareExtension, KeyShareEntry, HRRKeyShareExtension

from unit_tests.mocksock import MockSocket

srv_raw_key = str(
    "-----BEGIN RSA PRIVATE KEY-----\n"\
    "MIICXQIBAAKBgQDRCQR5qRLJX8sy1N4BF1G1fml1vNW5S6o4h3PeWDtg7JEn+jIt\n"\
    "M/NZekrGv/+3gU9C9ixImJU6U+Tz3kU27qw0X+4lDJAZ8VZgqQTp/MWJ9Dqz2Syy\n"\
    "yQWUvUNUj90P9mfuyDO5rY/VLIskdBNOzUy0xvXvT99fYQE+QPP7aRgo3QIDAQAB\n"\
    "AoGAVSLbE8HsyN+fHwDbuo4I1Wa7BRz33xQWLBfe9TvyUzOGm0WnkgmKn3LTacdh\n"\
    "GxgrdBZXSun6PVtV8I0im5DxyVaNdi33sp+PIkZU386f1VUqcnYnmgsnsUQEBJQu\n"\
    "fUZmgNM+bfR+Rfli4Mew8lQ0sorZ+d2/5fsM0g80Qhi5M3ECQQDvXeCyrcy0u/HZ\n"\
    "FNjIloyXaAIvavZ6Lc6gfznCSfHc5YwplOY7dIWp8FRRJcyXkA370l5dJ0EXj5Gx\n"\
    "udV9QQ43AkEA34+RxjRk4DT7Zo+tbM/Fkoi7jh1/0hFkU5NDHweJeH/mJseiHtsH\n"\
    "KOcPGtEGBBqT2KNPWVz4Fj19LiUmmjWXiwJBAIBs49O5/+ywMdAAqVblv0S0nweF\n"\
    "4fwne4cM+5ZMSiH0XsEojGY13EkTEon/N8fRmE8VzV85YmkbtFWgmPR85P0CQQCs\n"\
    "elWbN10EZZv3+q1wH7RsYzVgZX3yEhz3JcxJKkVzRCnKjYaUi6MweWN76vvbOq4K\n"\
    "G6Tiawm0Duh/K4ZmvyYVAkBppE5RRQqXiv1KF9bArcAJHvLm0vnHPpf1yIQr5bW6\n"\
    "njBuL4qcxlaKJVGRXT7yFtj2fj0gv3914jY2suWqp8XJ\n"\
    "-----END RSA PRIVATE KEY-----\n"\
    )

srv_raw_certificate = str(
    "-----BEGIN CERTIFICATE-----\n"\
    "MIIB9jCCAV+gAwIBAgIJAMyn9DpsTG55MA0GCSqGSIb3DQEBCwUAMBQxEjAQBgNV\n"\
    "BAMMCWxvY2FsaG9zdDAeFw0xNTAxMjExNDQzMDFaFw0xNTAyMjAxNDQzMDFaMBQx\n"\
    "EjAQBgNVBAMMCWxvY2FsaG9zdDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA\n"\
    "0QkEeakSyV/LMtTeARdRtX5pdbzVuUuqOIdz3lg7YOyRJ/oyLTPzWXpKxr//t4FP\n"\
    "QvYsSJiVOlPk895FNu6sNF/uJQyQGfFWYKkE6fzFifQ6s9kssskFlL1DVI/dD/Zn\n"\
    "7sgzua2P1SyLJHQTTs1MtMb170/fX2EBPkDz+2kYKN0CAwEAAaNQME4wHQYDVR0O\n"\
    "BBYEFJtvXbRmxRFXYVMOPH/29pXCpGmLMB8GA1UdIwQYMBaAFJtvXbRmxRFXYVMO\n"\
    "PH/29pXCpGmLMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQADgYEAkOgC7LP/\n"\
    "Rd6uJXY28HlD2K+/hMh1C3SRT855ggiCMiwstTHACGgNM+AZNqt6k8nSfXc6k1gw\n"\
    "5a7SGjzkWzMaZC3ChBeCzt/vIAGlMyXeqTRhjTCdc/ygRv3NPrhUKKsxUYyXRk5v\n"\
    "g/g6MwxzXfQP3IyFu3a9Jia/P89Z1rQCNRY=\n"\
    "-----END CERTIFICATE-----\n"\
    )

class TestTLSConnection(unittest.TestCase):

    def test_client_with_server_responing_with_SHA256_on_TLSv1_1(self):
        # socket to generate the faux response
        gen_sock = MockSocket(bytearray(0))

        gen_record_layer = RecordLayer(gen_sock)
        gen_record_layer.version = (3, 2)

        server_hello = ServerHello().create(
                version=(3, 2),
                random=bytearray(32),
                session_id=bytearray(0),
                cipher_suite=CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                certificate_type=None,
                tackExt=None,
                next_protos_advertised=None)

        for res in gen_record_layer.sendRecord(server_hello):
            if res in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # test proper
        sock = MockSocket(gen_sock.sent[0])

        conn = TLSConnection(sock)

        with self.assertRaises(TLSLocalAlert) as err:
            conn.handshakeClientCert()

        self.assertEqual(err.exception.description,
                         AlertDescription.illegal_parameter)

    def test_server_with_client_proposing_SHA256_on_TLSv1_1(self):
        gen_sock = MockSocket(bytearray(0))

        gen_record_layer = RecordLayer(gen_sock)
        gen_record_layer.version = (3, 0)

        ciphers = [CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                   CipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA256,
                   0x88, # TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA
                   CipherSuite.TLS_EMPTY_RENEGOTIATION_INFO_SCSV]

        client_hello = ClientHello().create(version=(3, 2),
                                            random=bytearray(32),
                                            session_id=bytearray(0),
                                            cipher_suites=ciphers)

        for res in gen_record_layer.sendRecord(client_hello):
            if res in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # test proper
        sock = MockSocket(gen_sock.sent[0])

        conn = TLSConnection(sock)

        srv_private_key = parsePEMKey(srv_raw_key, private=True)
        srv_cert_chain = X509CertChain([X509().parse(srv_raw_certificate)])
        with self.assertRaises(TLSLocalAlert) as err:
            conn.handshakeServer(certChain=srv_cert_chain,
                                 privateKey=srv_private_key)

        self.assertEqual(err.exception.description,
                         AlertDescription.handshake_failure)

    def test_client_with_server_responing_without_EMS(self):
        # socket to generate the faux response
        gen_sock = MockSocket(bytearray(0))

        gen_record_layer = RecordLayer(gen_sock)
        gen_record_layer.version = (3, 2)

        server_hello = ServerHello().create(
                version=(3, 3),
                random=bytearray(32),
                session_id=bytearray(0),
                cipher_suite=CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                certificate_type=None,
                tackExt=None,
                next_protos_advertised=None)

        for res in gen_record_layer.sendRecord(server_hello):
            if res in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # test proper
        sock = MockSocket(gen_sock.sent[0])

        hs = HandshakeSettings()
        hs.requireExtendedMasterSecret = True

        conn = TLSConnection(sock)

        with self.assertRaises(TLSLocalAlert) as err:
            conn.handshakeClientCert(settings=hs)

        self.assertEqual(err.exception.description,
                         AlertDescription.insufficient_security)

    def test_server_with_client_not_using_required_EMS(self):
        gen_sock = MockSocket(bytearray(0))

        gen_record_layer = RecordLayer(gen_sock)
        gen_record_layer.version = (3, 0)

        ciphers = [CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                   CipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA256,
                   CipherSuite.TLS_EMPTY_RENEGOTIATION_INFO_SCSV]

        client_hello = ClientHello().create(version=(3, 3),
                                            random=bytearray(32),
                                            session_id=bytearray(0),
                                            cipher_suites=ciphers)

        for res in gen_record_layer.sendRecord(client_hello):
            if res in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # test proper
        sock = MockSocket(gen_sock.sent[0])

        conn = TLSConnection(sock)

        hs = HandshakeSettings()
        hs.requireExtendedMasterSecret = True

        srv_private_key = parsePEMKey(srv_raw_key, private=True)
        srv_cert_chain = X509CertChain([X509().parse(srv_raw_certificate)])
        with self.assertRaises(TLSLocalAlert) as err:
            conn.handshakeServer(certChain=srv_cert_chain,
                                 privateKey=srv_private_key,
                                 settings=hs)

        self.assertEqual(err.exception.description,
                         AlertDescription.insufficient_security)

    def test_client_with_server_responing_with_wrong_session_id_in_TLS1_3(self):
        # socket to generate the faux response
        gen_sock = MockSocket(bytearray(0))

        gen_record_layer = RecordLayer(gen_sock)
        gen_record_layer.version = (3, 3)

        srv_ext = []
        srv_ext.append(SrvSupportedVersionsExtension().create((3, 4)))
        srv_ext.append(ServerKeyShareExtension().create(
            KeyShareEntry().create(
            GroupName.secp256r1, bytearray(b'\x03' + b'\x01' * 32))))

        server_hello = ServerHello().create(
                version=(3, 3),
                random=bytearray(32),
                session_id=bytearray(b"test"),
                cipher_suite=CipherSuite.TLS_AES_128_GCM_SHA256,
                certificate_type=None,
                tackExt=None,
                next_protos_advertised=None,
                extensions=srv_ext)

        for res in gen_record_layer.sendRecord(server_hello):
            if res in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # test proper
        sock = MockSocket(gen_sock.sent[0])

        conn = TLSConnection(sock)

        with self.assertRaises(TLSLocalAlert) as err:
            conn.handshakeClientCert()

        self.assertEqual(err.exception.description,
                         AlertDescription.illegal_parameter)

    def test_client_with_server_responing_with_wrong_session_id_in_TLS1_3_HRR(self):
        # socket to generate the faux response
        gen_sock = MockSocket(bytearray(0))

        gen_record_layer = RecordLayer(gen_sock)
        gen_record_layer.version = (3, 3)

        srv_ext = []
        srv_ext.append(SrvSupportedVersionsExtension().create((3, 4)))
        srv_ext.append(HRRKeyShareExtension().create(
            GroupName.secp521r1))

        server_hello = ServerHello().create(
                version=(3, 3),
                random=TLS_1_3_HRR,
                session_id=bytearray(b"test"),
                cipher_suite=CipherSuite.TLS_AES_128_GCM_SHA256,
                certificate_type=None,
                tackExt=None,
                next_protos_advertised=None,
                extensions=srv_ext)

        for res in gen_record_layer.sendRecord(server_hello):
            if res in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # test proper
        sock = MockSocket(gen_sock.sent[0])

        conn = TLSConnection(sock)

        with self.assertRaises(TLSLocalAlert) as err:
            conn.handshakeClientCert()

        self.assertEqual(err.exception.description,
                         AlertDescription.illegal_parameter)


    def prepare_mock_socket_with_handshake_failure(self):
        alertObj = Alert().create(AlertDescription.handshake_failure)
        alert = alertObj.write()
        header = RecordHeader3().create((3, 3), ContentType.alert, len(alert))
        return MockSocket(header.write() + alert)

    def test_padding_extension_with_hello_over_256(self):
        sock = self.prepare_mock_socket_with_handshake_failure()

        conn = TLSConnection(sock)
        # create hostname extension
        with self.assertRaises(TLSRemoteAlert):
            # use serverName with 252 bytes
            settings = HandshakeSettings()
            settings.maxVersion = (3, 3)
            settings.keyShares = []
            conn.handshakeClientCert(settings=settings,
                serverName='aaaaaaaaaabbbbbbbbbbccccccccccdddddddddd.' +
                           'eeeeeeeeeeffffffffffgggggggggghhhhhhhhhh.' +
                           'iiiiiiiiiijjjjjjjjjjkkkkkkkkkkllllllllll.' +
                           'mmmmmmmmmmnnnnnnnnnnoooooooooopppppppppp.' +
                           'qqqqqqqqqqrrrrrrrrrrsssssssssstttttttttt.' +
                           'uuuuuuuuuuvvvvvvvvvvwwwwwwwwwwxxxxxxxxxx.' +
                           'y.com')

        self.assertEqual(len(sock.sent), 1)
        # check for version and content type (handshake)
        self.assertEqual(sock.sent[0][0:3], bytearray(
            b'\x16' +
            b'\x03\x03'))
        # check for handshake message type (client_hello)
        self.assertEqual(sock.sent[0][5:6], bytearray(
            b'\x01'))
        self.assertEqual(sock.sent[0][5:9], bytearray(
            b'\x01\x00\x02\x00'))
        # 5 bytes is record layer header, 4 bytes is handshake protocol header
        self.assertEqual(len(sock.sent[0]) - 5 - 4, 512)

    def test_keyingMaterialExporter_tls1_3_sha384(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._recordLayer.version = (3, 4)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        conn.session.exporterMasterSecret = \
            bytearray(b'0123456789abcdef0123456789abcdef0123456789abcdef' +
                      b'0123456789abcdef0123456789abcdef0123456789abcdef')

        mat = conn.keyingMaterialExporter(bytearray(b'test'), 20)
        self.assertEqual(mat,
            bytearray(b';\x96;\x08U*\xbd1\x0fL5^0\xe1*I\x9e\xd3\xcb0'))

    def test_keyingMaterialExporter_tls1_3_sha256(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._recordLayer.version = (3, 4)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        conn.session.exporterMasterSecret = \
            bytearray(b'0123456789abcdef0123456789abcdef' +
                      b'0123456789abcdef0123456789abcdef')

        mat = conn.keyingMaterialExporter(bytearray(b'test'), 20)
        self.assertEqual(mat,
            bytearray(b'W_h\x10\x83\xc0XD\x0fw\x0e\xfc/\x92\x8f\xb3\xfd\x13\x96\xd9'))

    def test_keyingMaterialExporter_tls1_2_sha384(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._clientRandom = bytearray(b'012345678901234567890123456789ab')
        conn._serverRandom = bytearray(b'987654321098765432109876543210ab')
        conn._recordLayer.version = (3, 3)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

        mat = conn.keyingMaterialExporter(bytearray(b'test'), 20)
        self.assertEqual(mat,
                bytearray(b'1\xb8X\xef\x9b\xa5\n9p\x13\xfaxXI\\$\xdf\xb5\xc7i'))

    def test_keyingMaterialExporter_ssl3(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._clientRandom = bytearray(b'012345678901234567890123456789ab')
        conn._serverRandom = bytearray(b'987654321098765432109876543210ab')
        conn._recordLayer.version = (3, 0)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_DHE_RSA_WITH_AES_128_CBC_SHA

        with self.assertRaises(ValueError):
            conn.keyingMaterialExporter(bytearray(b'test'), 20)

    def test_keyingMaterialExporter_invalid_label(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._clientRandom = bytearray(b'012345678901234567890123456789ab')
        conn._serverRandom = bytearray(b'987654321098765432109876543210ab')
        conn._recordLayer.version = (3, 1)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_DHE_RSA_WITH_AES_128_CBC_SHA

        with self.assertRaises(ValueError):
            conn.keyingMaterialExporter(bytearray(b'server finished'), 20)

    def test_keyingMaterialExporter_tls1_2_sha256(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._clientRandom = bytearray(b'012345678901234567890123456789ab')
        conn._serverRandom = bytearray(b'987654321098765432109876543210ab')
        conn._recordLayer.version = (3, 3)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

        mat = conn.keyingMaterialExporter(bytearray(b'test'), 20)
        self.assertEqual(mat,
                bytearray(b'\xe6EQ\x93\xcb!\xe7\x87\x1e\xdd\x85' +
                          b'\xb2\x08|\xc9\xbfDh\r\x90'))

    def test_keyingMaterialExporter_tls1_1(self):
        sock = MockSocket(bytearray(0))
        conn = TLSConnection(sock)
        conn._clientRandom = bytearray(b'012345678901234567890123456789ab')
        conn._serverRandom = bytearray(b'987654321098765432109876543210ab')
        conn._recordLayer.version = (3, 2)
        conn.session = Session()
        conn.session.cipherSuite = \
            CipherSuite.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA

        mat = conn.keyingMaterialExporter(bytearray(b'test'), 20)
        self.assertEqual(mat,
                bytearray(b'\x1f\xf8\x18\x01:\x9f\x15a\xd5x\xaa;Y>' +
                          b'\xafG\x92AH\xa4'))

class TestRealConnection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cert_chain = X509CertChain([X509().parse(srv_raw_certificate)])
        cls.certKey = parsePEMKey(srv_raw_key, private=True)

    def setUp(self):
        self.client_socket, self.server_socket = socket.socketpair()

        self.server_socket.settimeout(1)
        self.server = TLSConnection(self.server_socket)

        def server_process(server):
            settings = HandshakeSettings()
            settings.maxVersion = (3, 3)
            server.handshakeServer(certChain=self.cert_chain,
                                   privateKey=self.certKey)
            ret = server.read(min=len("client hello"))
            if ret != bytearray(b"client hello"):
                raise AssertionError("incorrect query")
            server.write(bytearray(b"Conn OK"))
            server.close()

        self.thread = threading.Thread(target=server_process,
                                       args=(self.server, ))
        self.thread.start()

    def test_connection_no_rsa_pss(self):
        settings = HandshakeSettings()
        settings.maxVersion = (3, 3)
        # exclude pss as the keys in this module are too small for
        # the needed salt size for sha512 hash
        settings.rsaSchemes = ["pkcs1"]
        conn = TLSConnection(self.client_socket)
        conn.handshakeClientCert(serverName="localhost",
                                 settings=settings)
        self.assertIn(conn.session.cipherSuite, CipherSuite.aeadSuites)
        conn.write(bytearray(b"client hello"))
        ret = conn.read(min=len("Conn OK"))
        self.assertEqual(ret, bytearray(b"Conn OK"))

    def tearDown(self):
        self.thread.join()
        self.client_socket.close()
        self.server_socket.close()


if __name__ == '__main__':
    unittest.main()
