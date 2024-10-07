# Copyright (c) 2015, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from unit_tests.mocksock import MockSocket
from tlslite.messagesocket import MessageSocket
from tlslite.defragmenter import Defragmenter
from tlslite.messages import Message
from tlslite.constants import ContentType

class TestMessageSocket(unittest.TestCase):
    def test___init__(self):
        msgSock = MessageSocket(None, None)

        self.assertIsNotNone(msgSock)

    def test_recvMessage(self):
        defragmenter = Defragmenter()
        defragmenter.add_static_size(21, 2)

        sock = MockSocket(bytearray(
            b'\x15' +           # message type
            b'\x03\x03' +       # TLS version
            b'\x00\x04' +       # payload length
            b'\xff\xff' +       # first message
            b'\xbb\xbb'         # second message
            ))

        msgSock = MessageSocket(sock, defragmenter)

        for res in msgSock.recvMessage():
            if res in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        self.assertIsNotNone(res)

        header, parser = res

        self.assertEqual(header.type, 21)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(header.length, 0)
        self.assertEqual(parser.bytes, bytearray(b'\xff\xff'))

        res = None

        for res in msgSock.recvMessage():
            if res in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        self.assertIsNotNone(res)

        header, parser = res

        self.assertEqual(header.type, 21)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(header.length, 0)
        self.assertEqual(parser.bytes, bytearray(b'\xbb\xbb'))

    def test_recvMessage_with_unfragmentable_type(self):
        defragmenter = Defragmenter()
        defragmenter.add_static_size(21, 2)

        sock = MockSocket(bytearray(
            b'\x17' +       # message type
            b'\x03\x03' +   # TLS version
            b'\x00\x06' +   # payload length
            b'\x00\x04' +
            b'\xff'*4
            ))

        msgSock = MessageSocket(sock, defragmenter)

        for res in msgSock.recvMessage():
            if res in (0, 1):
                self.assertTrue(False, "Blocking read")
            else:
                break

        self.assertIsNotNone(res)

        header, parser = res

        self.assertEqual(header.type, 23)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(header.length, 6)
        self.assertEqual(parser.bytes, bytearray(b'\x00\x04' + b'\xff'*4))

    def test_recvMessage_with_blocking_socket(self):
        defragmenter = Defragmenter()
        defragmenter.add_static_size(21, 2)

        sock = MockSocket(bytearray(
            b'\x15' +           # message type
            b'\x03\x03' +       # TLS version
            b'\x00\x02' +       # payload length
            b'\xff\xff'         # message
            ),
            blockEveryOther=True,
            maxRet=1)

        msgSock = MessageSocket(sock, defragmenter)

        gotBlocked = False
        for res in msgSock.recvMessage():
            if res in (0, 1):
                gotBlocked = True
            else:
                break

        self.assertTrue(gotBlocked)
        self.assertIsNotNone(res)

        header, parser = res

        self.assertEqual(header.type, 21)
        self.assertEqual(header.version, (3, 3))
        self.assertEqual(parser.bytes, bytearray(b'\xff\xff'))

    def test_recvMessageBlocking(self):
        defragmenter = Defragmenter()
        defragmenter.add_static_size(21, 2)

        sock = MockSocket(bytearray(
            b'\x15' +           # message type
            b'\x03\x03' +       # TLS version
            b'\x00\x02' +       # payload length
            b'\xff\xff'         # message
            ),
            blockEveryOther=True,
            maxRet=1)

        msgSock = MessageSocket(sock, defragmenter)

        res = msgSock.recvMessageBlocking()

        self.assertIsNotNone(res)

        header, parser = res

        self.assertEqual(header.type, 21)
        self.assertEqual(parser.bytes, bytearray(b'\xff\xff'))

    def test_flush(self):
        sock = MockSocket(bytearray())

        msgSock = MessageSocket(sock, None)

        for res in msgSock.flush():
            if res in (0, 1):
                self.assertTrue(False, "Blocking flush")
            else:
                break

        self.assertEqual(len(sock.sent), 0)

        for res in msgSock.flush():
            if res in (0, 1):
                self.assertTrue(False, "Blocking flush")
            else:
                break

        self.assertEqual(len(sock.sent), 0)

    def test_queueMessage(self):
        sock = MockSocket(bytearray())

        msgSocket = MessageSocket(sock, None)

        msg = Message(ContentType.alert, bytearray(b'\xff\xbb'))

        for res in msgSocket.queueMessage(msg):
            if res in (0, 1):
                self.assertTrue(False, "Blocking queue")
            else:
                break

        self.assertEqual(len(sock.sent), 0)

        msg = Message(ContentType.alert, bytearray(b'\xff\xaa'))

        for res in msgSocket.queueMessage(msg):
            if res in (0, 1):
                self.assertTrue(False, "Blocking queue")
            else:
                break

        self.assertEqual(len(sock.sent), 0)

        for res in msgSocket.flush():
            if res in (0, 1):
                self.assertTrue(False, "Blocking flush")
            else:
                break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(sock.sent[0], bytearray(
            b'\x15' +
            b'\x00\x00' +
            b'\x00\x04' +
            b'\xff\xbb' +
            b'\xff\xaa'))

    def test_queueMessage_with_conflicting_types(self):
        sock = MockSocket(bytearray())

        msgSock = MessageSocket(sock, None)
        msgSock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(b'\xaa\xaa\xaa'))

        for res in msgSock.queueMessage(msg):
            if res in (0, 1):
                self.assertTrue(False, "Blocking queue")
            else:
                break

        self.assertEqual(len(sock.sent), 0)

        msg = Message(ContentType.alert, bytearray(b'\x02\x01'))

        for res in msgSock.queueMessage(msg):
            if res in (0, 1):
                self.assertTrue(False, "Blocking queue")
            else:
                break

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x16' +
            b'\x03\x03' +
            b'\x00\x03' +
            b'\xaa'*3), sock.sent[0])

        for res in msgSock.flush():
            if res in (0, 1):
                self.assertTrue(False, "Blocking flush")
            else:
                break

        self.assertEqual(len(sock.sent), 2)
        self.assertEqual(bytearray(
            b'\x15' +
            b'\x03\x03' +
            b'\x00\x02' +
            b'\x02\x01'), sock.sent[1])

    def test_queueMessage_with_conflicting_types_and_blocking_socket(self):
        sock = MockSocket(bytearray(), blockEveryOther=True)
        sock.blockWrite = True

        msgSock = MessageSocket(sock, None)
        msgSock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(b'\xaa\xaa\xaa'))

        blocked = False
        for res in msgSock.queueMessage(msg):
            if res in (0, 1):
                blocked = True
            else:
                break

        # no write so no blocking
        self.assertFalse(blocked)
        self.assertEqual(len(sock.sent), 0)

        msg = Message(ContentType.alert, bytearray(b'\x02\x01'))

        blocked = False
        for res in msgSock.queueMessage(msg):
            if res in (0, 1):
                blocked = True
            else:
                break

        # blocked once, so one write
        self.assertTrue(blocked)
        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x16' +
            b'\x03\x03' +
            b'\x00\x03' +
            b'\xaa'*3), sock.sent[0])

        sock.blockWrite = True

        blocked = False
        for res in msgSock.flush():
            if res in (0, 1):
                blocked = True
            else:
                break

        # blocked once, so one write
        self.assertTrue(blocked)
        self.assertEqual(len(sock.sent), 2)
        self.assertEqual(bytearray(
            b'\x15' +
            b'\x03\x03' +
            b'\x00\x02' +
            b'\x02\x01'), sock.sent[1])

    def test_sendMessage(self):
        sock = MockSocket(bytearray(), blockEveryOther=True)
        sock.blockWrite = True

        msgSock = MessageSocket(sock, None)
        msgSock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(b'\xaa\xaa\xaa'))

        blocked = False
        for res in msgSock.queueMessage(msg):
            if res in (0, 1):
                blocked = True
            else:
                break

        # no write so no blocking
        self.assertFalse(blocked)
        self.assertEqual(len(sock.sent), 0)

        msg = Message(ContentType.alert, bytearray(b'\x02\x01'))

        blocked = False
        for res in msgSock.sendMessage(msg):
            if res in (0, 1):
                blocked = True
            else:
                break

        self.assertTrue(blocked)
        self.assertEqual(len(sock.sent), 2)
        self.assertEqual(bytearray(
            b'\x16' +
            b'\x03\x03' +
            b'\x00\x03' +
            b'\xaa'*3), sock.sent[0])
        self.assertEqual(bytearray(
            b'\x15' +
            b'\x03\x03' +
            b'\x00\x02' +
            b'\x02\x01'), sock.sent[1])

    def test_sendMessageBlocking(self):
        sock = MockSocket(bytearray(), blockEveryOther=True)
        sock.blockWrite = True

        msgSock = MessageSocket(sock, None)
        msgSock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(b'\xaa\xaa\xaa'))

        blocked = False
        for res in msgSock.queueMessage(msg):
            if res in (0, 1):
                blocked = True
            else:
                break

        # no write so no blocking
        self.assertFalse(blocked)
        self.assertEqual(len(sock.sent), 0)

        msg = Message(ContentType.alert, bytearray(b'\x02\x01'))

        msgSock.sendMessageBlocking(msg)

        self.assertEqual(len(sock.sent), 2)
        self.assertEqual(bytearray(
            b'\x16' +
            b'\x03\x03' +
            b'\x00\x03' +
            b'\xaa'*3), sock.sent[0])
        self.assertEqual(bytearray(
            b'\x15' +
            b'\x03\x03' +
            b'\x00\x02' +
            b'\x02\x01'), sock.sent[1])

    def test_queueMessageBlocking(self):
        sock = MockSocket(bytearray(), blockEveryOther=True)
        sock.blockWrite = True

        msgSock = MessageSocket(sock, None)
        msgSock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(b'\xaa\xaa\xaa'))

        msgSock.queueMessageBlocking(msg)

        self.assertEqual(len(sock.sent), 0)

        msg = Message(ContentType.alert, bytearray(b'\x02\x01'))

        msgSock.queueMessageBlocking(msg)

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x16' +
            b'\x03\x03' +
            b'\x00\x03' +
            b'\xaa'*3), sock.sent[0])

    def test_flushBlocking(self):
        sock = MockSocket(bytearray())
        msgSock = MessageSocket(sock, None)

        msgSock.flushBlocking()

        self.assertEqual(len(sock.sent), 0)

    def test_flushBlocking_with_data(self):
        sock = MockSocket(bytearray(), blockEveryOther=True)
        sock.blockWrite = True

        msgSock = MessageSocket(sock, None)
        msgSock.version = (3, 3)

        msg = Message(ContentType.handshake, bytearray(b'\xaa\xaa\xaa'))

        msgSock.queueMessageBlocking(msg)

        self.assertEqual(len(sock.sent), 0)

        msgSock.flushBlocking()

        self.assertEqual(len(sock.sent), 1)
        self.assertEqual(bytearray(
            b'\x16' +
            b'\x03\x03' +
            b'\x00\x03' +
            b'\xaa'*3), sock.sent[0])
