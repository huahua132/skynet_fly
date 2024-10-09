# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
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

import socket
import errno
from tlslite.tlsrecordlayer import TLSRecordLayer
from tlslite.messages import Message, ClientHello, ServerHello, Certificate, \
        ServerHelloDone, ClientKeyExchange, ChangeCipherSpec, Finished, \
        RecordHeader3
from tlslite.errors import TLSAbruptCloseError, TLSLocalAlert, \
        TLSAbruptCloseError, TLSInternalError, TLSClosedConnectionError
from tlslite.extensions import TLSExtension
from tlslite.constants import ContentType, HandshakeType, CipherSuite, \
        CertificateType
from tlslite.mathtls import PRF_1_2, calc_key
from tlslite.x509 import X509
from tlslite.x509certchain import X509CertChain
from tlslite.utils.keyfactory import parsePEMKey
from tlslite.utils.codec import Parser
from unit_tests.mocksock import MockSocket

class TestTLSRecordLayer(unittest.TestCase):
    def test___init__(self):
        record_layer = TLSRecordLayer(None)

        self.assertIsNotNone(record_layer)
        self.assertIsInstance(record_layer, TLSRecordLayer)

    def test__getNextRecord(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ))
        sock = TLSRecordLayer(mockSock)
        sock.version = (3,3)

        # XXX using private method!
        for result in sock._getNextRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result
        data = data.bytes

        self.assertEqual(data, bytearray(4))
        self.assertEqual(header.type, ContentType.handshake)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(header.length, 0)

    def test__getNextRecord_with_trickling_socket(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ), maxRet=1)

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        for result in sock._getNextRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result
        data = data.bytes

        self.assertEqual(bytearray(4), data)

    def test__getNextRecord_with_blocking_socket(self):
        mockSock = mock.MagicMock()
        mockSock.recv.side_effect = socket.error(errno.EWOULDBLOCK)

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        gen = sock._getNextRecord()

        self.assertEqual(0, next(gen))

    def test__getNextRecord_with_errored_out_socket(self):
        mockSock = mock.MagicMock()
        mockSock.recv.side_effect = socket.error(errno.ETIMEDOUT)

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        gen = sock._getNextRecord()

        with self.assertRaises(socket.error):
            next(gen)

    def test__getNextRecord_with_empty_socket(self):
        mockSock = mock.MagicMock()
        mockSock.recv.side_effect = [bytearray(0)]

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        gen = sock._getNextRecord()

        with self.assertRaises(TLSAbruptCloseError):
            next(gen)

    def test__getNextRecord_with_slow_socket(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ), maxRet=1, blockEveryOther=True)

        sock = TLSRecordLayer(mockSock)

        gotRetry = False
        # XXX using private method!
        for result in sock._getNextRecord():
            if result in (0, 1):
                gotRetry = True
            else: break

        header, data = result
        data = data.bytes

        self.assertTrue(gotRetry)
        self.assertEqual(bytearray(4), data)

    def test__getNextRecord_with_malformed_record(self):
        mockSock = MockSocket(bytearray(
            b'\x01' +           # wrong type
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x01' +       # length
            b'\x00'))

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        gen = sock._getNextRecord()

        with self.assertRaises(TLSLocalAlert) as context:
            next(gen)

        self.assertEqual(str(context.exception), "illegal_parameter")

    def test__getNextRecord_with_too_big_record(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\xff\xff' +       # length
            b'\x00'*65536))

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        gen = sock._getNextRecord()

        with self.assertRaises(TLSLocalAlert) as context:
            next(gen)

        self.assertEqual(str(context.exception), "record_overflow")

    def test__getNextRecord_with_SSL2_record(self):
        mockSock = MockSocket(bytearray(
            b'\x80' +           # tag
            b'\x04' +           # length
            b'\x00'*4))

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        for result in sock._getNextRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result
        data = data.bytes

        self.assertTrue(header.ssl2)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual(4, header.length)
        self.assertEqual((2, 0), header.version)

        self.assertEqual(bytearray(4), data)

    def test__getNextRecord_with_not_complete_SSL2_record(self):
        mockSock = MockSocket(bytearray(
            b'\x80' +           # tag
            b'\x04' +           # length
            b'\x00'*3))

        sock = TLSRecordLayer(mockSock)

        # XXX using private method!
        for result in sock._getNextRecord():
            break

        self.assertEqual(0, result)

    def test__getNextRecord_with_SSL2_record_with_incomplete_header(self):
        mockSock = MockSocket(bytearray(
            b'\x80'             # tag
            ))

        sock = TLSRecordLayer(mockSock)

        # XXX using private method
        for result in sock._getNextRecord():
            break

        self.assertEqual(0, result)

    def test__getNextRecord_with_empty_handshake(self):

        mock_sock = MockSocket(bytearray(
            b'\x16' +           # handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x00'         # length
            ))

        record_layer = TLSRecordLayer(mock_sock)

        with self.assertRaises(TLSLocalAlert):
            for result in record_layer._getNextRecord():
                if result in (0,1):
                    raise Exception("blocking socket")
                else:
                    break

    def test__getNextRecord_with_multiple_messages_in_single_record(self):

        mock_sock = MockSocket(bytearray(
            b'\x16' +           # handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x35' +       # length
            # server hello
            b'\x02' +           # type - server hello
            b'\x00\x00\x26' +   # length
            b'\x03\x03' +       # TLSv1.2
            b'\x01'*32 +        # random
            b'\x00' +           # session ID length
            b'\x00\x2f' +       # cipher suite selected
            b'\x00' +           # compression method
            # certificate
            b'\x0b' +           # type - certificate
            b'\x00\x00\x03'     # length
            b'\x00\x00\x00'     # length of certificates
            # server hello done
            b'\x0e' +           # type - server hello done
            b'\x00\x00\x00'     # length
            ))

        record_layer = TLSRecordLayer(mock_sock)

        results = []
        for result in record_layer._getNextRecord():
            if result in (0,1):
                raise Exception("blocking")
            else:
                results.append(result)
                if len(results) == 3:
                    break

        header, p = results[0]

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual(42, len(p.bytes))
        self.assertEqual(HandshakeType.server_hello, p.bytes[0])

        # XXX generator stops as soon as a message was read
        #self.assertEqual(1, len(results))
        #return

        header, p = results[1]

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual(7, len(p.bytes))
        self.assertEqual(HandshakeType.certificate, p.bytes[0])

        header, p = results[2]

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual(4, len(p.bytes))
        self.assertEqual(HandshakeType.server_hello_done, p.bytes[0])

    def test__sendMsg(self):
        mockSock = MockSocket(bytearray(0))
        sock = TLSRecordLayer(mockSock)
        sock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(10))

        # XXX using private method
        for result in sock._sendMsg(msg, False):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else: break

        self.assertEqual(len(mockSock.sent), 1)
        self.assertEqual(bytearray(
            b'\x16' +           # handshake message
            b'\x03\x03' +       # version
            b'\x00\x0a' +       # payload length
            b'\x00'*10          # payload
            ), mockSock.sent[0])

    def test__sendMsg_with_very_slow_socket(self):
        mockSock = MockSocket(bytearray(0), maxWrite=1, blockEveryOther=True)
        sock = TLSRecordLayer(mockSock)

        msg = Message(ContentType.handshake, bytearray(b'\x32'*2))

        gotRetry = False
        # XXX using private method!
        for result in sock._sendMsg(msg, False):
            if result in (0, 1):
                gotRetry = True
            else: break

        self.assertTrue(gotRetry)
        self.assertEqual([
            bytearray(b'\x16'),  # handshake message
            bytearray(b'\x00'), bytearray(b'\x00'), # version (unset)
            bytearray(b'\x00'), bytearray(b'\x02'), # payload length
            bytearray(b'\x32'), bytearray(b'\x32')],
            mockSock.sent)

    def test__sendMsg_with_errored_out_socket(self):
        mockSock = mock.MagicMock()
        mockSock.send.side_effect = socket.error(errno.ETIMEDOUT)

        sock = TLSRecordLayer(mockSock)

        msg = Message(ContentType.handshake, bytearray(10))

        gen = sock._sendMsg(msg, False)

        with self.assertRaises(TLSAbruptCloseError):
            next(gen)

    def test__sendMsg_with_large_message(self):

        mock_sock = MockSocket(bytearray(0))

        record_layer = TLSRecordLayer(mock_sock)

        client_hello = ClientHello().create((3,3), bytearray(32), bytearray(0),
                [x for x in range(2**15-1)])

        gen = record_layer._sendMsg(client_hello)

        for result in gen:
            if result in (0, 1):
                self.assertTrue(False, "blocking")
            else:
                break

        # The maximum length that can be sent in single record is 2**14
        # record layer adds 5 byte on top of that
        self.assertEqual(len(mock_sock.sent), 5)
        for msg in mock_sock.sent:
            self.assertTrue(len(msg) <= 2**14 + 5)

    def test_write_with_BEAST_record_splitting(self):
        mock_sock = MockSocket(bytearray(0))
        record_layer = TLSRecordLayer(mock_sock)

        record_layer.version = (3, 1)
        record_layer.closed = False
        record_layer._recordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48),
                bytearray(32),
                bytearray(32),
                None)
        record_layer._recordLayer.changeWriteState()

        record_layer.write(bytearray(32))

        self.assertEqual(len(mock_sock.sent), 2)
        msg1 = mock_sock.sent[0]
        self.assertEqual(bytearray(
            b'\x17'  +      # application data
            b'\x03\x01' +   # TLSv1.0
            b'\x00\x20'     # length 32 bytes = data(1) + MAC(20) + padding(11)
            ), msg1[:5])
        self.assertEqual(len(msg1[5:]), 32)

        msg2 = mock_sock.sent[1]
        self.assertEqual(bytearray(
            b'\x17'  +      # application data
            b'\x03\x01' +   # TLSv1.0
            b'\x00\x40'     # length 64 bytes = data(31) + MAC(20) + padding(13)
            ), msg2[:5])
        self.assertEqual(len(msg2[5:]), 64)

    def test_write_with_BEAST_record_splitting_and_small_write(self):
        mock_sock = MockSocket(bytearray(0))
        record_layer = TLSRecordLayer(mock_sock)

        record_layer.version = (3, 1)
        record_layer.closed = False
        record_layer._recordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48),
                bytearray(32),
                bytearray(32),
                None)
        record_layer._recordLayer.changeWriteState()

        record_layer.write(bytearray(1))

        self.assertEqual(len(mock_sock.sent), 1)
        msg1 = mock_sock.sent[0]
        self.assertEqual(bytearray(
            b'\x17'  +      # application data
            b'\x03\x01' +   # TLSv1.0
            b'\x00\x20'     # length 32 bytes = data(1) + MAC(20) + padding(11)
            ), msg1[:5])
        self.assertEqual(len(msg1[5:]), 32)

    def test_write_with_BEAST_record_splitting_and_empty_write(self):
        mock_sock = MockSocket(bytearray(0))
        record_layer = TLSRecordLayer(mock_sock)

        record_layer.version = (3, 1)
        record_layer.closed = False
        record_layer._recordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48),
                bytearray(32),
                bytearray(32),
                None)
        record_layer._recordLayer.changeWriteState()

        record_layer.write(bytearray(0))

        self.assertEqual(len(mock_sock.sent), 1)
        msg1 = mock_sock.sent[0]
        self.assertEqual(bytearray(
            b'\x17'  +      # application data
            b'\x03\x01' +   # TLSv1.0
            b'\x00\x20'     # length 32 bytes = data(0) + MAC(20) + padding(12)
            ), msg1[:5])
        self.assertEqual(len(msg1[5:]), 32)

    def test__getMsg(self):

        mock_sock = MockSocket(
                bytearray(
                b'\x16' +           # handshake
                b'\x03\x03' +       # TLSv1.2
                b'\x00\x3a' +       # payload length
                b'\x02' +           # Server Hello
                b'\x00\x00\x36' +   # hello length
                b'\x03\x03' +       # TLSv1.2
                b'\x00'*32 +        # random
                b'\x00' +           # session ID length
                b'\x00\x2f' +       # cipher suite selected (AES128-SHA)
                b'\x00' +           # compression null
                b'\x00\x0e' +       # extensions length
                b'\xff\x01' +       # renegotiation_info
                b'\x00\x01' +       # ext length
                b'\x00' +           # renegotiation info ext length - 0
                b'\x00\x23' +       # session_ticket
                b'\x00\x00' +       # ext length
                b'\x00\x0f' +       # heartbeat extension
                b'\x00\x01' +       # ext length
                b'\x01'))           # peer is allowed to send requests

        record_layer = TLSRecordLayer(mock_sock)

        gen = record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello)

        message = next(gen)

        self.assertEqual(ServerHello, type(message))
        self.assertEqual((3,3), message.server_version)
        self.assertEqual(0x002f, message.cipher_suite)

    def test__getMsg_with_fragmented_message(self):

        mock_sock = MockSocket(
                bytearray(
                b'\x16' +           # handshake
                b'\x03\x03' +       # TLSv1.2
                b'\x00\x06' +       # payload length
                b'\x02' +           # Server Hello
                b'\x00\x00\x36' +   # hello length
                b'\x03\x03' +       # TLSv1.2
                # fragment end
                b'\x16' +           # type - handshake
                b'\x03\x03' +       # TLSv1.2
                b'\x00\x34' +       # payload length:
                b'\x00'*32 +        # random
                b'\x00' +           # session ID length
                b'\x00\x2f' +       # cipher suite selected (AES128-SHA)
                b'\x00' +           # compression null
                b'\x00\x0e' +       # extensions length
                b'\xff\x01' +       # renegotiation_info
                b'\x00\x01' +       # ext length
                b'\x00' +           # renegotiation info ext length - 0
                b'\x00\x23' +       # session_ticket
                b'\x00\x00' +       # ext length
                b'\x00\x0f' +       # heartbeat extension
                b'\x00\x01' +       # ext length
                b'\x01'))           # peer is allowed to send requests

        record_layer = TLSRecordLayer(mock_sock)

        gen = record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello)

        message = next(gen)

        if message in (0,1):
            raise Exception("blocking")

        self.assertEqual(ServerHello, type(message))
        self.assertEqual((3,3), message.server_version)
        self.assertEqual(0x002f, message.cipher_suite)

    def test__getMsg_with_oversized_message(self):

        mock_sock = MockSocket(
                bytearray(
                b'\x16' +           # handshake
                b'\x03\x03' +       # TLSv1.2
                b'\x40\x01' +       # payload length 2**14+1
                b'\x02' +           # Server Hello
                b'\x00\x3f\xfd' +   # hello length 2**14+1-1-3
                b'\x03\x03' +       # TLSv1.2
                b'\x00'*32 +        # random
                b'\x00' +           # session ID length
                b'\x00\x2f' +       # cipher suite selected (AES128-SHA)
                b'\x00' +           # compression null
                b'\x3f\xd5' +       # extensions length: 2**14+1-1-3-2-32-6
                b'\xff\xff' +       # extension type (padding)
                b'\x3f\xd1' +       # extension length: 2**14+1-1-3-2-32-6-4
                b'\x00'*16337       # value
                ))

        record_layer = TLSRecordLayer(mock_sock)

        gen = record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello)

        with self.assertRaises(TLSLocalAlert):
            message = next(gen)

    #
    # Temporary tests below
    #

    def test_full_connection_with_RSA_kex(self):

        clnt_sock, srv_sock = socket.socketpair()

        #
        # client part
        #
        record_layer = TLSRecordLayer(clnt_sock)

        record_layer._handshakeStart(client=True)
        record_layer.version = (3,3)

        client_hello = ClientHello()
        client_hello = client_hello.create((3,3), bytearray(32),
                bytearray(0), [CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA],
                None, None, False, False, None)

        for result in record_layer._sendMsg(client_hello):
            if result in (0,1):
                raise Exception("blocking socket")

        #
        # server part
        #

        srv_record_layer = TLSRecordLayer(srv_sock)

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

        srv_private_key = parsePEMKey(srv_raw_key, private=True)
        srv_cert_chain = X509CertChain([X509().parse(srv_raw_certificate)])

        srv_record_layer._handshakeStart(client=False)

        srv_record_layer.version = (3,3)

        for result in srv_record_layer._getMsg(ContentType.handshake,
                HandshakeType.client_hello):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        srv_client_hello = result
        self.assertEqual(ClientHello, type(srv_client_hello))

        srv_cipher_suite = CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA
        srv_session_id = bytearray(0)

        srv_server_hello = ServerHello().create(
                (3,3), bytearray(32), srv_session_id, srv_cipher_suite,
                CertificateType.x509, None, None)

        srv_msgs = []
        srv_msgs.append(srv_server_hello)
        srv_msgs.append(Certificate(CertificateType.x509).
                create(srv_cert_chain))
        srv_msgs.append(ServerHelloDone())
        for result in srv_record_layer._sendMsgs(srv_msgs):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break
        srv_record_layer._versionCheck = True

        #
        # client part
        #

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_hello = result
        self.assertEqual(ServerHello, type(server_hello))

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.certificate, CertificateType.x509):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_certificate = result
        self.assertEqual(Certificate, type(server_certificate))

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello_done):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_hello_done = result
        self.assertEqual(ServerHelloDone, type(server_hello_done))

        public_key = server_certificate.cert_chain.getEndEntityPublicKey()

        premasterSecret = bytearray(48)
        premasterSecret[0] = 3 # 'cause we negotiatied TLSv1.2
        premasterSecret[1] = 3

        encryptedPreMasterSecret = public_key.encrypt(premasterSecret)

        client_key_exchange = ClientKeyExchange(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                (3,3))
        client_key_exchange.createRSA(encryptedPreMasterSecret)

        for result in record_layer._sendMsg(client_key_exchange):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        master_secret = calc_key((3, 3), premasterSecret,
                                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                b"master secret",
                                client_random=client_hello.random,
                                server_random=server_hello.random,
                                output_length=48)

        record_layer._calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                master_secret, client_hello.random, server_hello.random,
                None)

        for result in record_layer._sendMsg(ChangeCipherSpec()):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        record_layer._changeWriteState()

        handshake_hashes = record_layer._handshake_hash.digest('sha256')
        verify_data = PRF_1_2(master_secret, b'client finished',
                handshake_hashes, 12)

        finished = Finished((3,3)).create(verify_data)
        for result in record_layer._sendMsg(finished):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        #
        # server part
        #

        for result in srv_record_layer._getMsg(ContentType.handshake,
                HandshakeType.client_key_exchange,
                srv_cipher_suite):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        srv_client_key_exchange = result

        srv_premaster_secret = srv_private_key.decrypt(
                srv_client_key_exchange.encryptedPreMasterSecret)

        self.assertEqual(bytearray(b'\x03\x03' + b'\x00'*46),
                srv_premaster_secret)

        srv_master_secret = calc_key(srv_record_layer.version,
                                    srv_premaster_secret,
                                    CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                    b"master secret",
                                    client_random=srv_client_hello.random,
                                    server_random=srv_server_hello.random,
                                    output_length=48)

        srv_record_layer._calcPendingStates(srv_cipher_suite,
                srv_master_secret, srv_client_hello.random,
                srv_server_hello.random, None)

        for result in srv_record_layer._getMsg(ContentType.change_cipher_spec):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        srv_change_cipher_spec = result
        self.assertEqual(ChangeCipherSpec, type(srv_change_cipher_spec))

        srv_record_layer._changeReadState()

        srv_handshakeHashes = srv_record_layer._handshake_hash.digest('sha256')
        srv_verify_data = PRF_1_2(srv_master_secret, b"client finished",
                srv_handshakeHashes, 12)

        for result in srv_record_layer._getMsg(ContentType.handshake,
                HandshakeType.finished):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break
        srv_finished = result
        self.assertEqual(Finished, type(srv_finished))
        self.assertEqual(srv_verify_data, srv_finished.verify_data)

        for result in srv_record_layer._sendMsg(ChangeCipherSpec()):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        srv_record_layer._changeWriteState()

        srv_handshakeHashes = srv_record_layer._handshake_hash.digest('sha256')
        srv_verify_data = PRF_1_2(srv_master_secret, b"server finished",
                srv_handshakeHashes, 12)

        for result in srv_record_layer._sendMsg(Finished((3,3)).create(
                srv_verify_data)):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        srv_record_layer._handshakeDone(resumed=False)

        #
        # client part
        #

        for result in record_layer._getMsg(ContentType.change_cipher_spec):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        change_cipher_spec = result
        self.assertEqual(ChangeCipherSpec, type(change_cipher_spec))

        record_layer._changeReadState()

        handshake_hashes = record_layer._handshake_hash.digest('sha256')
        server_verify_data = PRF_1_2(master_secret, b'server finished',
                handshake_hashes, 12)

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.finished):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_finished = result
        self.assertEqual(Finished, type(server_finished))
        self.assertEqual(server_verify_data, server_finished.verify_data)

        record_layer._handshakeDone(resumed=False)

        # try sending data
        record_layer.write(bytearray(b'text\n'))

        # try recieving data
        data = srv_record_layer.read(10)
        self.assertEqual(data, bytearray(b'text\n'))

        record_layer.close()
        srv_record_layer.close()

    def test_write_heartbeat_to_closed(self):
        mock_sock = MockSocket(bytearray(0))
        record_layer = TLSRecordLayer(mock_sock)

        record_layer.closed = True

        with self.assertRaises(TLSClosedConnectionError):
            record_layer.send_heartbeat_request(b'0', 1)

    def test_write_heartbeat_with_incorrect_settings(self):
        mock_sock = MockSocket(bytearray(0))
        record_layer = TLSRecordLayer(mock_sock)

        record_layer.closed = False
        record_layer.heartbeat_supported = False
        record_layer.heartbeat_can_send = True

        with self.assertRaises(TLSInternalError):
            record_layer.send_heartbeat_request(b'0', 1)

        record_layer.heartbeat_supported = True
        record_layer.heartbeat_can_send = False

        with self.assertRaises(TLSInternalError):
             record_layer.send_heartbeat_request(b'0', 1)

    @unittest.skip("needs external TLS server")
    def test_full_connection_with_external_server(self):

        # TODO test is slow (100ms) move to integration test suite
        #
        # start a regular TLS server locally before running this test
        # e.g.: openssl s_server -key localhost.key -cert localhost.crt

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("127.0.0.1", 4433))

        record_layer = TLSRecordLayer(sock)

        record_layer._handshakeStart(client=True)
        record_layer.version = (3,3)

        client_hello = ClientHello()
        client_hello = client_hello.create((3,3), bytearray(32),
                bytearray(0), [CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA],
                None, None, False, False, None)

        for result in record_layer._sendMsg(client_hello):
            if result in (0,1):
                raise Exception("blocking socket")

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_hello = result
        self.assertEqual(ServerHello, type(server_hello))

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.certificate, CertificateType.x509):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_certificate = result
        self.assertEqual(Certificate, type(server_certificate))

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.server_hello_done):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_hello_done = result
        self.assertEqual(ServerHelloDone, type(server_hello_done))

        public_key = server_certificate.cert_chain.getEndEntityPublicKey()

        premasterSecret = bytearray(48)
        premasterSecret[0] = 3 # 'cause we negotiatied TLSv1.2
        premasterSecret[1] = 3

        encryptedPreMasterSecret = public_key.encrypt(premasterSecret)

        client_key_exchange = ClientKeyExchange(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                (3,3))
        client_key_exchange.createRSA(encryptedPreMasterSecret)

        for result in record_layer._sendMsg(client_key_exchange):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        master_secret = calc_key((3, 3), premasterSecret,
                                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                b"master secret",
                                client_random=client_hello.random,
                                server_random=server_hello.random,
                                output_length=48)

        record_layer._calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                master_secret, client_hello.random, server_hello.random,
                None)

        for result in record_layer._sendMsg(ChangeCipherSpec()):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        record_layer._changeWriteState()

        handshake_hashes = record_layer._handshake_hash.digest('sha256')
        verify_data = PRF_1_2(master_secret, b'client finished',
                handshake_hashes, 12)

        finished = Finished((3,3)).create(verify_data)
        for result in record_layer._sendMsg(finished):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        for result in record_layer._getMsg(ContentType.change_cipher_spec):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        change_cipher_spec = result
        self.assertEqual(ChangeCipherSpec, type(change_cipher_spec))

        record_layer._changeReadState()

        handshake_hashes = record_layer._handshake_hash.digest('sha256')
        server_verify_data = PRF_1_2(master_secret, b'server finished',
                handshake_hashes, 12)

        for result in record_layer._getMsg(ContentType.handshake,
                HandshakeType.finished):
            if result in (0,1):
                raise Exception("blocking socket")
            else:
                break

        server_finished = result
        self.assertEqual(Finished, type(server_finished))
        self.assertEqual(server_verify_data, server_finished.verify_data)

        record_layer._handshakeDone(resumed=False)

        record_layer.write(bytearray(b'text\n'))

        record_layer.close()

