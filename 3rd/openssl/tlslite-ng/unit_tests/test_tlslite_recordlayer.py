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

import os
import socket
import errno

import tlslite.utils.cryptomath as cryptomath
from tlslite.messages import Message, ApplicationData, RecordHeader3, \
        ClientHello, ClientMasterKey, ServerHello2, RecordHeader2
from tlslite.recordlayer import RecordSocket, ConnectionState, RecordLayer
from tlslite.constants import ContentType, CipherSuite
from unit_tests.mocksock import MockSocket
from tlslite.errors import TLSRecordOverflow, TLSIllegalParameterException,\
        TLSAbruptCloseError, TLSDecryptionFailed, TLSBadRecordMAC, \
        TLSUnexpectedMessage

class TestRecordSocket(unittest.TestCase):
    def test___init__(self):
        sock = RecordSocket(-42)

        self.assertIsNotNone(sock)
        self.assertEqual(sock.sock, -42)
        self.assertEqual(sock.version, (0, 0))

    def test_send(self):
        mockSock = MockSocket(bytearray(0))
        sock = RecordSocket(mockSock)
        sock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(10))

        for result in sock.send(msg):
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

    def test_send_SSLv2_message(self):
        mock_sock = MockSocket(bytearray(0))
        sock = RecordSocket(mock_sock)
        sock.version = (0, 2)

        msg = ClientHello(ssl2=True)
        msg.create((3, 3), random=bytearray(b'\xaa'*16),
                   session_id=bytearray(0),
                   cipher_suites=[CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                  CipherSuite.TLS_RSA_WITH_RC4_128_MD5])

        for result in sock.send(msg):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(mock_sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x80' +           # short header
            b'\x1f' +           # length - 31 bytes
            b'\x01' +           # CLIENT-HELLO
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x06' +       # cipher suite length
            b'\x00\x00' +       # session_id length
            b'\x00\x10' +       # Challange length
            b'\x00\x00\x2f' +   # cipher: TLS_RSA_WITH_AES_128_CBC_SHA
            b'\x00\x00\x04' +   # cipher: TLS_RSA_WITH_RC4_128_MD5
            b'\xaa'*16          # challange
            ), mock_sock.sent[0])

    def test_send_with_very_slow_socket(self):
        mockSock = MockSocket(bytearray(0), maxWrite=1, blockEveryOther=True)
        sock = RecordSocket(mockSock)

        msg = Message(ContentType.handshake, bytearray(b'\x32'*2))

        gotRetry = False
        for result in sock.send(msg):
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

    def test_send_with_errored_out_socket(self):
        mockSock = mock.MagicMock()
        mockSock.send.side_effect = socket.error(errno.ETIMEDOUT)

        sock = RecordSocket(mockSock)

        msg = Message(ContentType.handshake, bytearray(10))

        gen = sock.send(msg)

        with self.assertRaises(socket.error):
            next(gen)

    def test_recv(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ))
        sock = RecordSocket(mockSock)

        for result in sock.recv():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result

        self.assertEqual(data, bytearray(4))
        self.assertEqual(header.type, ContentType.handshake)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(header.length, 4)

    def test_recv_stops_itelf(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ))
        sock = RecordSocket(mockSock)

        for result in sock.recv():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")

        header, data = result

        self.assertEqual(data, bytearray(4))
        self.assertEqual(header.type, ContentType.handshake)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(header.length, 4)

    def test_recv_with_trickling_socket(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ), maxRet=1)

        sock = RecordSocket(mockSock)

        for result in sock.recv():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result

        self.assertEqual(bytearray(4), data)

    def test_recv_with_blocking_socket(self):
        mockSock = mock.MagicMock()
        mockSock.recv.side_effect = socket.error(errno.EWOULDBLOCK)

        sock = RecordSocket(mockSock)

        gen = sock.recv()

        self.assertEqual(0, next(gen))

    def test_recv_with_errored_out_socket(self):
        mockSock = mock.MagicMock()
        mockSock.recv.side_effect = socket.error(errno.ETIMEDOUT)

        sock = RecordSocket(mockSock)

        gen = sock.recv()

        with self.assertRaises(socket.error):
            next(gen)

    def test_recv_with_empty_socket(self):
        mockSock = mock.MagicMock()
        mockSock.recv.side_effect = [bytearray(0)]

        sock = RecordSocket(mockSock)

        gen = sock.recv()

        with self.assertRaises(TLSAbruptCloseError):
            next(gen)

    def test_recv_with_slow_socket(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x00'*4
            ), maxRet=1, blockEveryOther=True)

        sock = RecordSocket(mockSock)

        gotRetry = False
        for result in sock.recv():
            if result in (0, 1):
                gotRetry = True
            else: break

        header, data = result

        self.assertTrue(gotRetry)
        self.assertEqual(bytearray(4), data)

    def test_recv_with_malformed_record(self):
        mockSock = MockSocket(bytearray(
            b'\x01' +           # wrong type
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x01' +       # length
            b'\x00'))

        sock = RecordSocket(mockSock)

        gen = sock.recv()

        with self.assertRaises(TLSIllegalParameterException):
            next(gen)

    def test_recv_with_too_big_record(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\xff\xff' +       # length
            b'\x00'*65536))

        sock = RecordSocket(mockSock)

        gen = sock.recv()

        with self.assertRaises(TLSRecordOverflow):
            next(gen)


    def test_recv_with_empty_data(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +           # type - handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x00'))       # length

        sock = RecordSocket(mockSock)

        gen = sock.recv()

        for result in sock.recv():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result

        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual((3, 3), header.version)
        self.assertEqual(0, header.length)

        self.assertEqual(bytearray(0), data)

    def test_recv_with_SSL2_record(self):
        mockSock = MockSocket(bytearray(
            b'\x80' +           # tag
            b'\x04' +           # length
            b'\x00'*4))

        sock = RecordSocket(mockSock)

        for result in sock.recv():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, data = result

        self.assertTrue(header.ssl2)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual(4, header.length)
        self.assertEqual((2, 0), header.version)

        self.assertEqual(bytearray(4), data)

    def test_recv_with_not_complete_SSL2_record(self):
        mockSock = MockSocket(bytearray(
            b'\x80' +           # tag
            b'\x04' +           # length
            b'\x00'*3))

        sock = RecordSocket(mockSock)

        for result in sock.recv():
            break

        self.assertEqual(0, result)

    def test_recv_with_SSL2_record_with_incomplete_header(self):
        mockSock = MockSocket(bytearray(
            b'\x80'             # tag
            ))

        sock = RecordSocket(mockSock)

        for result in sock.recv():
            break

        self.assertEqual(0, result)

    def test_recv_with_long_SSL2_header(self):
        mockSock = MockSocket(bytearray(
            b'\x40' +  # security escape data
            b'\x04' +  # length
            b'\x00' +  # padding length
            b'\xaa'*4))

        sock = RecordSocket(mockSock)

        for result in sock.recv():
            if result in (0, 1):
                self.assertTrue(True, "blocking socket")
            else: break

        header, data = result

        self.assertTrue(header.ssl2)
        self.assertTrue(header.securityEscape)
        self.assertEqual(4, header.length)
        self.assertEqual((2, 0), header.version)

        self.assertEqual(bytearray(b'\xaa'*4), data)

    def test_recv_with_limited_recv_size(self):
        mockSock = MockSocket(bytearray(
            b'\x16' +  # type
            b'\x03\x03' +  # TLSv1.2
            b'\x04\x00' +  # 1024B
            b'\xff' * 1024))

        sock = RecordSocket(mockSock)
        sock.recv_record_limit = 256
        sock.tls13record = True

        gen = sock.recv()

        with self.assertRaises(TLSRecordOverflow):
            next(gen)


class TestConnectionState(unittest.TestCase):
    def test___init__(self):
        connState = ConnectionState()

        self.assertIsNotNone(connState)
        self.assertIsNone(connState.macContext)
        self.assertIsNone(connState.encContext)
        self.assertEqual(0, connState.seqnum)

    def test_getSeqNumBytes(self):
        connState = ConnectionState()

        self.assertEqual(bytearray(b'\x00'*8), connState.getSeqNumBytes())
        self.assertEqual(bytearray(b'\x00'*7 + b'\x01'),
                         connState.getSeqNumBytes())
        self.assertEqual(bytearray(b'\x00'*7 + b'\x02'),
                         connState.getSeqNumBytes())
        self.assertEqual(bytearray(b'\x00'*7 + b'\x03'),
                         connState.getSeqNumBytes())
        self.assertEqual(4, connState.seqnum)

class TestRecordLayer(unittest.TestCase):
    def test___init__(self):
        recordLayer = RecordLayer(None)

        self.assertIsNotNone(recordLayer)

        self.assertIsNone(recordLayer.getCipherName())
        self.assertIsNone(recordLayer.getCipherImplementation())
        self.assertFalse(recordLayer.isCBCMode())

    def test_sendRecord(self):
        sock = MockSocket(bytearray(0))
        recordLayer = RecordLayer(sock)

        hello = Message(ContentType.handshake, bytearray(10))

        for result in recordLayer.sendRecord(hello):
            if result in (0, 1):
                self.assertTrue(False, "Blocking write")
            else:
                break

        self.assertEqual(len(sock.sent), 1)

    def test_shutdown(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        # make sure it doesn't throw exceptions
        recordLayer.shutdown()

    def test_getCipherName(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        self.assertEqual('aes128', recordLayer.getCipherName())
        self.assertTrue(recordLayer.isCBCMode())

    def test_blockSize(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        self.assertEqual(16, recordLayer.blockSize)

    def test_blockSize_with_3DES(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        self.assertEqual(8, recordLayer.blockSize)

    def test_getCipherImplementation(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        if cryptomath.m2cryptoLoaded:
            self.assertEqual('openssl', recordLayer.getCipherImplementation())
        elif cryptomath.pycryptoLoaded:
            self.assertEqual('pycrypto', recordLayer.getCipherImplementation())
        else:
            self.assertEqual('python', recordLayer.getCipherImplementation())

    def test_sendRecord_with_encrypting_set_up_tls1_2(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLS1.2
            b'\x00\x30'         # length - 48 bytes (3 blocks)
            ))                  # (4 bytes of data + 20 bytes of MAC + IV)
        self.assertEqual(bytearray(
            b'\x48\x26\x1f\xc1\x9c\xde\x22\x92\xdd\xe4\x7c\xfc\x6f\x29\x52\xd6'+
            b'\xc5\xec\x44\x21\xca\xe3\xd1\x34\x64\xad\xff\xb1\xea\xfa\xd5\xe3'+
            b'\x9f\x73\xec\xa9\xa6\x82\x55\x8e\x3a\x8c\x94\x96\xda\x06\x09\x8d'
            ), sock.sent[0][5:])

    def test_sendRecord_with_encryption_tls1_3_aes_128_gcm(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(b'test')

        for result in recordLayer.sendRecord(app_data):
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +  # application_data
            b'\x03\x03' +  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            ))

    def test_recvRecord_with_encryption_tls1_3_aes_128_gcm_wrong_type(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(
            b'\x16'  # handshake
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        with self.assertRaises(TLSUnexpectedMessage) as exc:
            for result in recordLayer.recvRecord():
                # check if non-blocking socket
                self.assertNotIn(result, (0, 1))
                break

        self.assertIn('Invalid ContentType', str(exc.exception))
        self.assertIn('handshake', str(exc.exception))

    def test_recvRecord_with_encryption_tls1_3_aes_128_gcm_wrong_length(self):
        header = RecordHeader3().create((3, 3), 0x17, 0x14)
        buf = bytearray(
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            )

        recordLayer = RecordLayer(None)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        with self.assertRaises(TLSBadRecordMAC) as exc:
            # other way to test it is to patch the recv() method of the record
            # socket to return a header with wrong length
            recordLayer._decryptAndUnseal(header, buf)

        self.assertIn('Length mismatch', str(exc.exception))

    def test_recvRecord_with_encryption_tls1_3_aes_128_gcm_wrong_version(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(
            b'\x17'  # application_data
            b'\x03\x01'  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        with self.assertRaises(TLSIllegalParameterException) as exc:
            for result in recordLayer.recvRecord():
                # check if non-blocking socket
                self.assertNotIn(result, (0, 1))
                break

        self.assertIn('Unexpected version', str(exc.exception))
        self.assertIn('(3, 1)', str(exc.exception))

    def test_recvRecord_with_early_data_disallowed(self):
        # as the early_data_ok is set to False automatically after processing
        # check if early data can be also disabled by setting max_early_data
        # to 0
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(
            # undecryptable early_data
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x20'  # length
            b'\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f'
            b'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        # disallow early data
        recordLayer.max_early_data = 0
        recordLayer.early_data_ok = True

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                # check if non-blocking socket
                self.assertNotIn(result, (0, 1))
                break

    def test_recvRecord_with_early_data_allowed_post_early_data_recv(self):
        # check if a second instance of undecryptable data, after
        # receiving decryptable data is rejected
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(
            # undecryptable early_data
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x20'  # length
            b'\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f'
            b'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'
            # first valid record
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            # second undecryptable record
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x20'  # length
            b'\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f'
            b'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        # allow for early data
        recordLayer.max_early_data = 2**14
        recordLayer.early_data_ok = True

        for result in recordLayer.recvRecord():
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        head, parser = result

        self.assertEqual((3, 4), head.version)
        self.assertEqual(head.type, ContentType.application_data)
        self.assertEqual(bytearray(b'test'), parser.bytes)

        # verify that receiving next record will fail, even though early
        # data was acceptable before
        self.assertFalse(recordLayer.early_data_ok)

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                self.assertNotIn(result, (0, 1))
                break

        self.assertFalse(recordLayer.early_data_ok)
        self.assertEqual(recordLayer.max_early_data, 2**14)

    def test_recvRecord_with_early_data_allowed(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(
            # undecryptable early_data
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x20'  # length
            b'\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f'
            b'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'
            # more undecryptable early_data
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x20'  # length
            b'\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f'
            b'\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f'
            # first correct record
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        # allow for early data
        recordLayer.max_early_data = 2**14
        recordLayer.early_data_ok = True

        app_data = ApplicationData().create(b'test')

        for result in recordLayer.recvRecord():
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        head, parser = result

        self.assertEqual((3, 4), head.version)
        self.assertEqual(head.type, ContentType.application_data)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_recvRecord_with_encryption_tls1_3_aes_128_gcm(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(
            b'\x17'  # application_data
            b'\x03\x03'  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            b"\xe1\x90\x2d\xd1\xfd"
            b'u\xdd\xa0\xb1VYB&\xe8\x05\xb1~\xe5u\x9a\x0f'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()

        app_data = ApplicationData().create(b'test')

        for result in recordLayer.recvRecord():
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        head, parser = result

        self.assertEqual((3, 4), head.version)
        self.assertEqual(head.type, ContentType.application_data)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_sendRecord_with_encryption_tls1_3_aes_256_gcm(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_256_GCM_SHA384,
                                           bytearray(48),  # cl_traffic_sec
                                           bytearray(48),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(b'test')

        for result in recordLayer.sendRecord(app_data):
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +  # application_data
            b'\x03\x03' +  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'}\x17w_#'
            b'\xfc\\\xaf\x1ef6\x03X\xd2\xe3\x1c\xe4]\xcb\xb7\xbb'
            ))

    def test_sendRecord_with_encryption_tls1_3_chacha20(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        ciph = CipherSuite.TLS_CHACHA20_POLY1305_SHA256
        recordLayer.calcTLS1_3PendingState(ciph,
                                           bytearray(48),  # cl_traffic_sec
                                           bytearray(48),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(b'test')

        for result in recordLayer.sendRecord(app_data):
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +  # application_data
            b'\x03\x03' +  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'o\x9fO\x16\x07'
            b'\xbdUy\x17E6\n\xd9\x9cT\xec\xdav\x1f\xb4$'
            ))

    def test_sendRecord_with_padding_tls1_3(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True

        def padding_cb(length, contenttype, max_padding):
            return 100
        recordLayer.padding_cb = padding_cb

        ciph = CipherSuite.TLS_CHACHA20_POLY1305_SHA256
        recordLayer.calcTLS1_3PendingState(ciph,
                                           bytearray(48),  # cl_traffic_sec
                                           bytearray(48),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(b'test')

        for result in recordLayer.sendRecord(app_data):
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        # we expect length 121 bytes (= 0x79)
        #     4 B of application data
        #     1 B of content type
        #   100 B of padding
        #    16 B of authentication tag
        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +  # application_data
            b'\x03\x03' +  # hidden protocol version - TLS 1.x
            b'\x00\x79'  # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b"o\x9fO\x16\x07\x96\xfdHGf\x8d\xe3\x03\x1a\x93p\xb9\xf6" +
            b"\xf1\xafK\xbc\x92\xed\xdc\xa7\x02\xb0\x0e\x1e\x00\xd6\xc2" +
            b"\xf6\x10\xe5}\xb1T\x85om\xa4\xfa\x1aS\x1f\xab\xc6b\'\xe6f" +
            b"\xb3\xbe\xac\xfd\xed\x06\x93\xadbGMD\xd9\xb9\xca\xf6\x8b" +
            b"\xac\x07\x96\xe8\xd13)r\xbcNJ\x9d#YP@\x9b\x8ez\x06\xfb" +
            b"\x8f2\x8cz\xb7\xd6IP\xfa\xeezcQ\xf3"
            b"(\t\x8e\x0b\xf8\x02\xb4\x9du\xa0f\x88;\xb9\xfd\x87"))

    def test_sendRecord_with_malformed_inner_plaintext(self):
        # setup
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x : bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True
        self.assertEqual((3, 4), recordLayer.version)

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(b'\x00\x00\x00\x00')
        app_data.contentType = 0

        for result in recordLayer.sendRecord(app_data):
            # check if non-blocking socket
            self.assertNotIn(result, (0, 1))
            break
        self.assertEqual(len(sock.sent), 1)

        # verification of data
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +  # application_data
            b'\x03\x03' +  # hidden protocol version - TLS 1.x
            b'\x00\x15'  # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\x95\xf5^\xa5\xea'
            b'\xddV\x81z97\xaf\xf4\xd7g\xae\xd4\x89\x9b\xe6\xa9'
            ))

        # test proper
        sock = MockSocket(sock.sent[0])
        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 4)
        recordLayer.tls13record = True
        recordLayer.client = False

        recordLayer.calcTLS1_3PendingState(CipherSuite.TLS_AES_128_GCM_SHA256,
                                           bytearray(32),  # cl_traffic_sec
                                           bytearray(32),  # sr_traffic_sec
                                           None)  # implementations
        recordLayer.changeReadState()
        with self.assertRaises(TLSUnexpectedMessage):
            for result in recordLayer.recvRecord():
                # verify that it's a non-blocking socket
                self.assertNotIn(result, (0, 1))
                break

    def test_sendRecord_with_SHA256_tls1_2(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLS1.2
            b'\x00\x40'         # length - 64 bytes (4 blocks)
            ))                  # (4 bytes of data + 32 bytes of MAC + IV)
        self.assertEqual(bytearray(
            b'pd\x87\xde\xab\x9aU^\x7f\x7f\xa9\x00\xd14\'\x0c' +
            b'\xde\xa73r\x9f\xb0O\x0eo_\x93\xec-\xb1c^' +
            b'\x9a{\xde7g=\xef\x94\xd9K\xcc\x92\xe8\xa6\x10R' +
            b'\xe0"c:7\xa9\xd7}X\x00[\x88\xce\xfe|\t'
            ), sock.sent[0][5:])

    def test_sendRecord_with_encrypting_set_up_tls1_1(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 2)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x02' +       # TLS1.2
            b'\x00\x30'         # length - 48 bytes (3 blocks)
            ))                  # (4 bytes of data + 20 bytes of MAC + IV)
        self.assertEqual(bytearray(
            b'b\x8e\xee\xddV\\W=\x810\xd5\x0c\xae \x84\xa8' +
            b'^\x91\xa4d[\xe4\xde\x90\xee{f\xbb\xcd_\x1ao' +
            b'\xa8\x8c!k\xab\x03\x03\x19.\x1dFMt\x08h^'
            ), sock.sent[0][5:])

    def test_sendRecord_with_encrypting_set_up_tls1_0(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLS1.0
            b'\x00\x20'         # length - 48 bytes (3 blocks)
            ))                  # (4 bytes of data + 20 bytes of MAC)
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\xebK\x0ff\x9cI\n\x011\xd0w\x9d\x11Z\xb4\xe5' +
            b'D\xe9\xec\x8d\xdfd\xed\x94\x9f\xe6K\x08(\x08\xf6\xb7'
            ))

    def test_sendRecord_with_stream_cipher_and_tls1_0(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_RC4_128_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # SSL3
            b'\x00\x18'         # length - 24 bytes
            ))                  # (4 bytes of data + 20 bytes of MAC)
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'B\xb8H\xc6\xd7\\\x01\xe27\xa9\x86\xf2\xfdm!\x1d' +
            b'\xa1\xaf]Q%y5\x1e'
            ))

    def test_sendRecord_with_MD5_MAC_and_tls1_0(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_RC4_128_MD5,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # SSL3
            b'\x00\x14'         # length - 20 bytes
            ))                  # (4 bytes of data + 16 bytes of MAC)
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'0}R\xe3T\xce`\xf9\x8f\x9d\xe6r\xc4\xdf\xd9\xd5' +
            b'\xbf/sL'
            ))


    def test_sendRecord_with_AES256_cipher_and_tls1_0(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # SSL3
            b'\x00\x20'         # length - 32 bytes (2 blocks)
            ))                  # (4 bytes of data + 20 bytes of MAC)
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\xb8\xe5\xc5\x9c\xe6\xad\xf0uY\x19L\x17\xf8\xe7F3' +
            b'}\xcct\x84<j^\xdb\xa68\xd8\x08\x84pm\x97'
            ))

    def test_sendRecord_with_AES128GCM(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x1c'         # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\x00\x00\x00\x00\x00\x00\x00\x00Fy\xc0\x91' +
            b'A\x85\x82\xffk\x95\x8a51\x1e\xfb\x93e\xdd\xc1\xc7'))

    def test_recvRecord_with_AES128GCM(self):
        sock = MockSocket(bytearray(
            b'\x17' +
            b'\x03\x03' +
            b'\x00\x1c' +
            b'\x00\x00\x00\x00\x00\x00\x00\x00Fy\xc0\x91' +
            b'A\x85\x82\xffk\x95\x8a51\x1e\xfb\x93e\xdd\xc1\xc7'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else:
                break

        head, parser = result

        self.assertEqual((3, 3), head.version)
        self.assertEqual(head.type, ContentType.application_data)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_recvRecord_with_AES128GCM_too_short_data(self):
        sock = MockSocket(bytearray(
            b'\x17' +
            b'\x03\x03' +
            b'\x00\x07' +
            b'\x00\x00\x00\x00\x00\x00\x00'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                if result in (0, 1):
                    self.assertTrue(False, "blocking socket")
                else:
                    break

    def test_recvRecord_with_AES128GCM_too_short_nonce(self):
        sock = MockSocket(bytearray(
            b'\x17' +
            b'\x03\x03' +
            b'\x00\x0b' +
            b'\x00\x00\x00\x00\x00\x00\x00\x00Fy\xc0'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                if result in (0, 1):
                    self.assertTrue(False, "blocking socket")
                else:
                    break

    def test_recvRecord_with_AES128GCM_invalid_side(self):
        sock = MockSocket(bytearray(
            b'\x17' +
            b'\x03\x03' +
            b'\x00\x1c' +
            b'\x00\x00\x00\x00\x00\x00\x00\x00Fy\xc0\x91' +
            b'A\x85\x82\xffk\x95\x8a51\x1e\xfb\x93e\xdd\xc1\xc7'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = True

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                if result in (0, 1):
                    self.assertTrue(False, "blocking socket")
                else:
                    break

    def test_sendRecord_with_AES256GCM(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_256_GCM_SHA384,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x1c'         # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\x00\x00\x00\x00\x00\x00\x00\x00\xb5c\x15\x8c' +
            b'\xe3\x92H6l\x90\x19\xef\x96\xbfT}\xe8\xbaE\xa3'))

    def test_sendRecord_with_ChaCha20_draft00(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        ciph = CipherSuite.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_draft_00
        recordLayer.calcPendingStates(ciph,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x14'         # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'8k9<\xf3\xdc\x86d,\xf4\xb7\xe8L7\xecA\x7fi\xb1\xdc'))

    def test_recvRecord_with_ChaCha20_draft00(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x14' +       # length
            b'8k9<\xf3\xdc\x86d,\xf4\xb7\xe8L7\xecA\x7fi\xb1\xdc'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False

        ciph = CipherSuite.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_draft_00
        recordLayer.calcPendingStates(ciph,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else:
                break

        head, parser = result

        self.assertEqual((3, 3), head.version)
        self.assertEqual(head.type, ContentType.application_data)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_sendRecord_with_ChaCha20(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)

        ciph = CipherSuite.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
        recordLayer.calcPendingStates(ciph,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x14'         # length
            ))
        self.assertEqual(sock.sent[0][5:], bytearray(
            b's\x1e\xe8(+h0\x84\xbf\x96,\xbc\xdf\\\x8c\xad=\x95\xa1\x9a'))

    def test_recvRecord_with_ChaCha20(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x14' +       # length
            b's\x1e\xe8(+h0\x84\xbf\x96,\xbc\xdf\\\x8c\xad=\x95\xa1\x9a'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False

        ciph = CipherSuite.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
        recordLayer.calcPendingStates(ciph,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else:
                break

        head, parser = result

        self.assertEqual((3, 3), head.version)
        self.assertEqual(head.type, ContentType.application_data)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_sendRecord_with_3DES_cipher_and_tls1_0(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # SSL3
            b'\x00\x20'         # length - 32 bytes (2 blocks)
            ))                  # (4 bytes of data + 20 bytes of MAC)
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\xac\x12\xa55\x1a\x1f\xe2\xe5<\xb3[;\xc4\xa6\x9bF' +
            b'\x8d\x16\x8b\xa3N\xe6\xfa\x14\xa9\xb9\xc7\x08w\xf2V\xe2'
            ))

    def test_sendRecord_with_encrypting_set_up_ssl3(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 0)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x00' +       # SSL3
            b'\x00\x20'         # length - 48 bytes (3 blocks)
            ))                  # (4 bytes of data + 20 bytes of MAC)
        self.assertEqual(sock.sent[0][5:], bytearray(
            b'\xc5\x16y\xf9\ra\xd9=\xec\x8b\x93\'\xb7\x05\xe6\xad' +
            b'\xff\x842\xc7\xa2\x0byd\xab\x1a\xfd\xaf\x05\xd6\xba\x89'
            ))

    def test_if_padding_is_minimal_in_ssl3_low_end(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 0)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test of pad'))

        self.assertIsNotNone(app_data)
        self.assertEqual(len(app_data.write()), 11)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x00' +       # SSL3
            b'\x00\x20'         # length - 32 bytes (2 blocks)
            ))                  # (11 bytes of data + 20 bytes of MAC
                                #  + 1 byte of padding length)
        self.assertEqual(len(sock.sent[0][5:]), 32)

    def test_if_padding_is_minimal_in_ssl3_high_end(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 0)

        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test of padd'))

        self.assertIsNotNone(app_data)
        self.assertEqual(len(app_data.write()), 12)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0][:5], bytearray(
            b'\x17' +           # application data
            b'\x03\x00' +       # SSL3
            b'\x00\x30'         # length - 48 bytes (3 blocks)
            ))                  # (12 bytes of data + 20 bytes of MAC
                                #  + 15 bytes of padding
                                #  + 1 byte of padding length)
        self.assertEqual(len(sock.sent[0][5:]), 48)

    def test_sendRecord_with_wrong_SSL_version(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)

        with self.assertRaises(AssertionError):
            recordLayer.calcPendingStates(
                    CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                    bytearray(48), # master secret
                    bytearray(32), # client random
                    bytearray(32), # server random
                    None)

    def test_sendRecord_with_invalid_ciphersuite(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)

        with self.assertRaises(AssertionError):
            recordLayer.calcPendingStates(
                    CipherSuite.TLS_EMPTY_RENEGOTIATION_INFO_SCSV,
                    bytearray(48), # master secret
                    bytearray(32), # client random
                    bytearray(32), # server random
                    None)

    def test_sendRecord_with_slow_socket(self):
        mockSock = MockSocket(bytearray(0), maxWrite=1, blockEveryOther=True)
        sock = RecordLayer(mockSock)

        msg = Message(ContentType.handshake, bytearray(b'\x32'*2))

        gotRetry = False
        for result in sock.sendRecord(msg):
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

    def test_sendRecord_with_encryptThenMAC_and_unset_crypto_state(self):
        sock = MockSocket(bytearray(0))
        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)
        recordLayer.encryptThenMAC = True

        app_data = ApplicationData().create(bytearray(b'test'))

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLS version
            b'\x00\x04' +       # length
            b'test'), sock.sent[0])

    def test_sendRecord_with_encryptThenMAC_in_TLSv1_0(self):
        sock = MockSocket(bytearray(0))
        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLS version
            b'\x00\x24' +       # length - 1 block + 20 bytes of MAC
            b'\xc7\xd6\xaf:.MY\x80W\x81\xd2|5A#\xd5' +
            b'X\xcd\xdc\'o\xb3I\xdd-\xfc\tneq~\x0f' +
            b'd\xdb\xbdw'), sock.sent[0])

    def test_sendRecord_with_encryptThenMAC_in_TLSv1_2(self):
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        sock = MockSocket(bytearray(0))
        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLS version
            b'\x00\x34' +       # length - IV + 1 block + 20 bytes of MAC
            b'H&\x1f\xc1\x9c\xde"\x92\xdd\xe4|\xfco)R\xd6' +
            b'\x11~\xf2\xed\xa0l\x11\xb4\xb7\xbd\x1a-<w\xbb\xf2' +
            b'\xa4\x9bH}T\xcbT\x9d2\xed\xc5\xe1|\x82T\xf1' +
            b'\xf6\x19\xfcw'), sock.sent[0])

    def test_recvRecord(self):
        sock = MockSocket(bytearray(
            b'\x16' +           # handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x0e' +           # server hello done
            b'\x00\x00\x00'     # length
            ))
        recordLayer = RecordLayer(sock)

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        header, parser = result

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual((3, 3), header.version)
        self.assertEqual(bytearray(b'\x0e' + b'\x00'*3), parser.bytes)

    def test_recvRecord_with_slow_socket(self):
        sock = MockSocket(bytearray(
            b'\x16' +           # handshake
            b'\x03\x03' +       # TLSv1.2
            b'\x00\x04' +       # length
            b'\x0e' +           # server hello done
            b'\x00\x00\x00'     # length
            ), maxRet=3, blockEveryOther=True)
        recordLayer = RecordLayer(sock)

        wasBlocked = False
        for result in recordLayer.recvRecord():
            if result in (0, 1):
                wasBlocked = True
            else:
                break
        self.assertTrue(wasBlocked)

        header, parser = result

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.handshake, header.type)
        self.assertEqual((3, 3), header.version)
        self.assertEqual(bytearray(b'\x0e' + b'\x00'*3), parser.bytes)


    def test_recvRecord_with_encrypted_content_TLS1_1(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x02' +       # TLSv1.1
            b'\x00\x30' +       # length
            # data from test_sendRecord_with_encrypting_set_up_tls1_1
            b'b\x8e\xee\xddV\\W=\x810\xd5\x0c\xae \x84\xa8' +
            b'^\x91\xa4d[\xe4\xde\x90\xee{f\xbb\xcd_\x1ao' +
            b'\xa8\x8c!k\xab\x03\x03\x19.\x1dFMt\x08h^'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        header, parser = result

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.application_data, header.type)
        self.assertEqual((3, 2), header.version)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_recvRecord_with_encrypted_content_SSLv3(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x00' +       # SSLv3
            b'\x00\x20' +       # length
            # data from test_sendRecord_with_encrypting_set_up_ssl3
            b'\xc5\x16y\xf9\ra\xd9=\xec\x8b\x93\'\xb7\x05\xe6\xad' +
            b'\xff\x842\xc7\xa2\x0byd\xab\x1a\xfd\xaf\x05\xd6\xba\x89'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 0)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        header, parser = result

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.application_data, header.type)
        self.assertEqual((3, 0), header.version)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_recvRecord_with_stream_cipher_and_tls1_0(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLSv1.0
            b'\x00\x18' +       # length (24 bytes)
            # data from test_sendRecord_with_stream_cipher_and_tls1_0
            b'B\xb8H\xc6\xd7\\\x01\xe27\xa9\x86\xf2\xfdm!\x1d' +
            b'\xa1\xaf]Q%y5\x1e'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 1)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_RC4_128_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        header, parser = result

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.application_data, header.type)
        self.assertEqual((3, 1), header.version)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_recvRecord_with_stream_cipher_and_tls1_0_and_incorrect_data(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLSv1.0
            b'\x00\x18' +       # length (24 bytes)
            # data from test_sendRecord_with_stream_cipher_and_tls1_0
            # last byte changed from \x1e to \x0e
            b'B\xb8H\xc6\xd7\\\x01\xe27\xa9\x86\xf2\xfdm!\x1d' +
            b'\xa1\xaf]Q%y5\x0e'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 1)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_RC4_128_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                if result in (0, 1):
                    self.assertTrue(False, "Blocking read")
                else:
                    break

    def test_recvRecord_with_stream_cipher_and_tls1_0_and_too_short_data(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLSv1.0
            b'\x00\x13' +       # length (19 bytes)
            # data from test_sendRecord_with_stream_cipher_and_tls1_0
            b'B\xb8H\xc6\xd7\\\x01\xe27\xa9\x86\xf2\xfdm!\x1d' +
            b'\xa1\xaf]'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 1)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_RC4_128_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        with self.assertRaises(TLSBadRecordMAC):
            for result in recordLayer.recvRecord():
                if result in (0, 1):
                    self.assertTrue(False, "Blocking read")
                else:
                    break

    def test_recvRecord_with_invalid_length_payload(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x02' +       # TLSv1.1
            b'\x00\x2f' +       # length
            b'b\x8e\xee\xddV\\W=\x810\xd5\x0c\xae \x84\xa8' +
            b'^\x91\xa4d[\xe4\xde\x90\xee{f\xbb\xcd_\x1ao' +
            b'\xa8\x8c!k\xab\x03\x03\x19.\x1dFMt\x08h'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSDecryptionFailed):
            next(gen)

    def test_recvRecord_with_zero_length_payload(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x02' +       # TLSv1.1
            b'\x00\x00'         # length
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_zero_length_payload_EtM(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLSv1.0
            b'\x00\x14' +       # length (just MAC alone, no data)
            b'A~\x1c\x88s\xdf\xa2sQ\xca\xdd\xb2\xd0\xdc\n\x94\x8e\xc8W\x04'
            ))

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 1)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_too_long_application_data_for_record_size_limit(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        # constructor for the data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 3)
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        msg = ApplicationData().create(bytearray(b'test'*1024))

        # create the data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x03' +       # SSLv3
            b'\x10\x30'         # length
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 4096+16+32)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 3)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()
        recordLayer.recv_record_limit = 256
        self.assertEqual(recordLayer.recv_record_limit, 256)

        with self.assertRaises(TLSRecordOverflow):
            for result in recordLayer.recvRecord():
                if result in (0, 1):
                    self.assertTrue(False, "Blocking socket")
                else: break

    def test_recvRecord_with_zero_filled_padding_in_SSLv3(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        # constructor for the data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 0)
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to return simple version of padding (SSLv3)
        def broken_padding(data):
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            paddingBytes = bytearray([0] * (paddingLength)) + \
                           bytearray([paddingLength])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x00' +       # SSLv3
            b'\x00\x20'         # length - 32 bytes
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 32)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 0)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else: break

        header, parser = result

        self.assertIsInstance(header, RecordHeader3)
        self.assertEqual(ContentType.application_data, header.type)
        self.assertEqual((3, 0), header.version)
        self.assertEqual(bytearray(b'test'), parser.bytes)

    def test_recvRecord_with_invalid_last_byte_in_padding(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)


        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to return invalid padding
        def broken_padding(data):
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            # make the value of last byte longer than all data
            paddingBytes = bytearray([paddingLength] * (paddingLength)) + \
                           bytearray([255])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x30'         # length - 48 bytes
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 48)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_invalid_middle_byte_in_padding(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)


        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to return invalid padding
        def broken_padding(data):
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            # make the value of last byte longer than all data
            paddingBytes = bytearray([paddingLength, 0] +
                                     [paddingLength] * (paddingLength-2)) + \
                           bytearray([paddingLength])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x30'         # length - 48 bytes
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 48)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_truncated_MAC(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)


        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to truncate padded data
        def broken_padding(data):
            data = data[:18]
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            paddingBytes = bytearray([paddingLength] * (paddingLength)) + \
                           bytearray([paddingLength])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x20'         # length - 32 bytes
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 32)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_invalid_MAC(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)


        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to make MAC bad
        def broken_padding(data):
            data[-1] ^= 255
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            paddingBytes = bytearray([paddingLength] * (paddingLength)) + \
                           bytearray([paddingLength])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x30'         # length - 48 bytes
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 48)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_encryptThenMAC_and_unset_crypto_state(self):
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLS version
            b'\x00\x04' +       # length
            b'test'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)
        recordLayer.client = False
        recordLayer.encryptThenMAC = True

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, parser = result

        self.assertEqual(parser.bytes, bytearray(b'test'))

    def test_recvRecord_with_encryptThenMAC_in_TLSv1_0(self):
        # data from test_sendRecord_with_encryptThenMAC_in_TLSv1_0
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x01' +       # TLS version
            b'\x00\x24' +       # length - 1 block + 20 bytes of MAC
            b'\xc7\xd6\xaf:.MY\x80W\x81\xd2|5A#\xd5' +
            b'X\xcd\xdc\'o\xb3I\xdd-\xfc\tneq~\x0f' +
            b'd\xdb\xbdw'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 1)
        recordLayer.encryptThenMAC = True
        recordLayer.client = False
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, parser = result

        self.assertEqual(parser.bytes, bytearray(b'test'))

    def test_recvRecord_with_encryptThenMAC_in_TLSv1_2(self):

        # data from test_sendRecord_with_encryptThenMAC_in_TLSv1_2
        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLS version
            b'\x00\x34' +       # length - IV + 1 block + 20 bytes of MAC
            b'H&\x1f\xc1\x9c\xde"\x92\xdd\xe4|\xfco)R\xd6' +
            b'\x11~\xf2\xed\xa0l\x11\xb4\xb7\xbd\x1a-<w\xbb\xf2' +
            b'\xa4\x9bH}T\xcbT\x9d2\xed\xc5\xe1|\x82T\xf1' +
            b'\xf6\x19\xfcw'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, parser = result

        self.assertEqual(parser.bytes, bytearray(b'test'))

    def test_recvRecord_with_encryptThenMAC_and_too_short_MAC(self):

        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLS version
            b'\x00\x10' +       # length - 16 bytes, less than 20 bytes of MAC
            b'H&\x1f\xc1\x9c\xde"\x92\xdd\xe4|\xfco)R\xd6'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_encryptThenMAC_with_modified_MAC(self):

        sock = MockSocket(bytearray(
            b'\x17' +           # application data
            b'\x03\x03' +       # TLS version
            b'\x00\x34' +       # length - IV + 1 block + 20 bytes of MAC
            b'H&\x1f\xc1\x9c\xde"\x92\xdd\xe4|\xfco)R\xd6' +
            b'\x11~\xf2\xed\xa0l\x11\xb4\xb7\xbd\x1a-<w\xbb\xf2' +
            b'\xa4\x9bH}T\xcbT\x9d2\xed\xc5\xe1|\x82T\xf1' +
            b'\xf6\x19\xfcW'))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (3, 3)
        recordLayer.client = False
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_encryptThenMAC_and_bad_size_encrypted_data(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)

        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.encryptThenMAC = True
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the encryption method to append a zero after data
        def broken_encrypt(buf):
            return buf + bytearray(1)

        sendingRecordLayer._writeState.encContext.encrypt = broken_encrypt

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x35'         # length - IV + data + padding + 1 + hash (20)
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 53)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSDecryptionFailed):
            next(gen)

    def test_recvRecord_with_encryptThenMAC_and_bad_last_padding_byte(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)


        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.encryptThenMAC = True
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to return invalid padding
        def broken_padding(data):
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            # make the value of last byte longer than all data
            paddingBytes = bytearray([paddingLength] * (paddingLength)) + \
                           bytearray([255])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x34'         # length - IV + data + padding + SHA-1
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 52)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_recvRecord_with_encryptThenMAC_and_SSLv3(self):

        # constructor for the data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 0)
        sendingRecordLayer.encryptThenMAC = True
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()
        self.assertTrue(sendingRecordLayer.encryptThenMAC)

        msg = ApplicationData().create(bytearray(b'test'))

        # create the data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x00' +       # SSLv3
            b'\x00\x24'         # length - IV + data + padding + SHA-1
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 36)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 0)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        header, parser = result

        self.assertEqual(parser.bytes, bytearray(b'test'))

    def test_recvRecord_with_encryptThenMAC_and_bad_padding_byte(self):
        # make sure the IV is predictible (all zero)
        patcher = mock.patch.object(os,
                                    'urandom',
                                    lambda x: bytearray(x))
        mock_random = patcher.start()
        self.addCleanup(patcher.stop)


        # constructor for the bad data
        sendingSocket = MockSocket(bytearray())

        sendingRecordLayer = RecordLayer(sendingSocket)
        sendingRecordLayer.version = (3, 2)
        sendingRecordLayer.encryptThenMAC = True
        sendingRecordLayer.calcPendingStates(
                CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                bytearray(48), # master secret
                bytearray(32), # client random
                bytearray(32), # server random
                None)
        sendingRecordLayer.changeWriteState()

        # change the padding method to return invalid padding
        def broken_padding(data):
            currentLength = len(data)
            blockLength = sendingRecordLayer.blockSize
            paddingLength = blockLength - 1 - (currentLength % blockLength)

            # make the value of second to last byte invalid (0)
            paddingBytes = bytearray([paddingLength] * (paddingLength-1)) + \
                           bytearray([0]) + \
                           bytearray([paddingLength])
            data += paddingBytes
            return data
        sendingRecordLayer.addPadding = broken_padding

        msg = ApplicationData().create(bytearray(b'test'))

        # create the bad data
        for result in sendingRecordLayer.sendRecord(msg):
            if result in (0, 1):
                self.assertTrue(False, "Blocking socket")
            else:
                break

        # sanity check the data
        self.assertEqual(1, len(sendingSocket.sent))
        self.assertEqual(bytearray(
            b'\x17' +           # app data
            b'\x03\x02' +       # tls 1.1
            b'\x00\x34'         # length - IV + data + padding + SHA-1
            ), sendingSocket.sent[0][:5])
        self.assertEqual(len(sendingSocket.sent[0][5:]), 52)

        # test proper
        sock = MockSocket(sendingSocket.sent[0])

        recordLayer = RecordLayer(sock)
        recordLayer.client = False
        recordLayer.version = (3, 2)
        recordLayer.encryptThenMAC = True
        recordLayer.calcPendingStates(CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                                      bytearray(48), # master secret
                                      bytearray(32), # client random
                                      bytearray(32), # server random
                                      None)
        recordLayer.changeReadState()

        gen = recordLayer.recvRecord()

        with self.assertRaises(TLSBadRecordMAC):
            next(gen)

    def test_sendRecord_with_ssl2(self):
        sock = MockSocket(bytearray(0))

        recordLayer = RecordLayer(sock)
        recordLayer.version = (0, 2)

        recordLayer.calcSSL2PendingStates(
                CipherSuite.SSL_CK_RC4_128_WITH_MD5,
                bytearray(24), # master secret
                bytearray(16), # client random
                bytearray(16), # server random
                None)

        # make sequence number correct
        hello = ClientHello().create((0, 2), bytearray(0), bytearray(0),
                                     [])
        master_key = ClientMasterKey()

        for result in recordLayer.sendRecord(hello):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break
        for result in recordLayer.sendRecord(master_key):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else:break
        # sequence number tweaking end

        recordLayer.changeWriteState()

        app_data = ApplicationData().create(bytearray(b'test'))

        self.assertIsNotNone(app_data)
        self.assertTrue(len(app_data.write()) > 3)

        for result in recordLayer.sendRecord(app_data):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break

        self.assertEqual(len(sock.sent), 3)
        self.assertEqual(sock.sent[2][:2], bytearray(
            b'\x80' +           # 2 byte header
            b'\x14'             # overall length
            ))
        self.assertEqual(sock.sent[2][2:], bytearray(
            b'\xa7\xaai.\x8a\x7ff\x12\xf8T\xcf[)\xc6\xd4\x11\xb85\x13\x0c'
            ))

    def test_recvRecord_with_ssl2(self):
        # prepare encrypted message
        srv_sock = MockSocket(bytearray(0))

        srv_recordLayer = RecordLayer(srv_sock)
        srv_recordLayer.client = False
        srv_recordLayer.version = (0, 2)
        # make the sequence number match
        srv_hello = ServerHello2()
        for result in srv_recordLayer.sendRecord(srv_hello):
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break
        # setup encryption
        srv_recordLayer.calcSSL2PendingStates(
                CipherSuite.SSL_CK_RC4_128_WITH_MD5,
                bytearray(24),  # master secret
                bytearray(16),  # client random
                bytearray(16),  # server random
                None)
        srv_recordLayer.changeWriteState()
        # actually encrypt the message
        srv_data = ApplicationData().create(bytearray(b'test'))
        for result in srv_recordLayer.sendRecord(srv_data):
            if result in (0, 1):
                self.assertRaises(False, "blocking socket")
            else: break

        #
        # check sanity of encrypted message
        #
        self.assertEqual(len(srv_sock.sent), 2)
        self.assertEqual(srv_sock.sent[1][:2], bytearray(
            b'\x80' +       # 2 byte header
            b'\x14'))       # overall length
        self.assertEqual(srv_sock.sent[1][2:], bytearray(
            b'(\x07\xf9\xde`\x80\xa77s\x13Q\xc6%\n\x7f\xbd\xb0,8\xc4'
            ))

        #
        # prepare socket for client
        #
        sock = MockSocket(srv_sock.sent[0] + srv_sock.sent[1])

        recordLayer = RecordLayer(sock)
        recordLayer.version = (0, 2)
        # first match the sequence numbers
        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break
        header, parser = result
        # setup encryption
        recordLayer.calcSSL2PendingStates(
                CipherSuite.SSL_CK_RC4_128_WITH_MD5,
                bytearray(24),  # master secret
                bytearray(16),  # client random
                bytearray(16),  # server random
                None)
        recordLayer.changeReadState()
        recordLayer.handshake_finished = True

        #
        # Test proper - recv encrypted message
        #
        for result in recordLayer.recvRecord():
            if result in (0, 1):
                self.assertTrue(False, "blocking socket")
            else: break
        header, parser = result

        self.assertIsInstance(header, RecordHeader2)
        self.assertEqual(header.type, ContentType.application_data)
        self.assertEqual(parser.bytes, bytearray(b'test'))
