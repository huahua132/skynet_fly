# Author: Hubert Kario (c) 2016
# see LICENCE file for legal information regarding use of this file

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

from tlslite.bufferedsocket import BufferedSocket

class TestBufferedSocket(unittest.TestCase):
    def setUp(self):
        self.raw_sock = mock.MagicMock()
        self.sock = BufferedSocket(self.raw_sock)

    def test___init__(self):
        self.assertFalse(self.sock.buffer_writes)
        self.assertIs(self.sock.socket, self.raw_sock)

    def test_send(self):
        data = mock.Mock()
        ret = self.sock.send(data)

        self.raw_sock.send.assert_called_once_with(data)
        self.assertIs(ret, self.raw_sock.send.return_value)

    def test_send_with_buffering(self):
        self.sock.buffer_writes = True

        data = mock.Mock()
        data.__len__ = mock.Mock(return_value=42)
        ret = self.sock.send(data)

        self.raw_sock.send.assert_not_called()
        self.assertEqual(ret, 42)

    def test_sendall(self):
        data = mock.Mock()
        ret = self.sock.sendall(data)

        self.assertIs(ret, self.raw_sock.sendall.return_value)
        self.raw_sock.sendall.assert_called_once_with(data)

    def test_sendall_with_buffering(self):
        self.sock.buffer_writes = True

        data = mock.Mock()
        ret = self.sock.sendall(data)

        self.raw_sock.sendall.assert_not_called()
        self.assertIsNone(ret)

    def test_flush(self):
        self.sock.flush()
        self.raw_sock.sendall.assert_not_called()

    def test_flush_with_data(self):
        self.sock.buffer_writes = True

        ret = self.sock.send(bytearray(b'abc'))

        self.assertEqual(ret, 3)
        self.raw_sock.sendall.assert_not_called()

        self.sock.flush()
        self.raw_sock.sendall.assert_called_once_with(bytearray(b'abc'))

    def test_flush_with_data_and_multiple_messages(self):
        self.sock.buffer_writes = True

        ret = self.sock.send(bytearray(b'abc'))
        self.assertEqual(ret, 3)

        ret = self.sock.send(bytearray(b'defg'))
        self.assertEqual(ret, 4)

        self.sock.flush()
        self.raw_sock.sendall.assert_called_once_with(bytearray(b'abcdefg'))

        self.sock.flush()
        self.raw_sock.sendall.assert_called_once_with(bytearray(b'abcdefg'))

    def test_recv(self):
        ret = self.sock.recv(10)

        self.raw_sock.recv.assert_called_once_with(4096)

    def test_getsockname(self):
        ret = self.sock.getsockname()

        self.raw_sock.getsockname.assert_called_once_with()
        self.assertIs(ret, self.raw_sock.getsockname.return_value)

    def test_getpeername(self):
        ret = self.sock.getpeername()

        self.raw_sock.getpeername.assert_called_once_with()
        self.assertIs(ret, self.raw_sock.getpeername.return_value)

    def test_settimeout(self):
        value = mock.Mock()
        ret = self.sock.settimeout(value)

        self.raw_sock.settimeout.assert_called_once_with(value)
        self.assertIs(ret, self.raw_sock.settimeout.return_value)

    def test_gettimeout(self):
        ret = self.sock.gettimeout()

        self.raw_sock.gettimeout.assert_called_once_with()
        self.assertIs(ret, self.raw_sock.gettimeout.return_value)

    def test_setsockopt(self):
        level = mock.Mock()
        optname = mock.Mock()
        value = mock.Mock()

        ret = self.sock.setsockopt(level, optname, value)

        self.raw_sock.setsockopt.assert_called_once_with(level, optname, value)
        self.assertIs(ret, self.raw_sock.setsockopt.return_value)

    def test_shutdown(self):
        self.sock.buffer_writes = True

        self.sock.send(bytearray(b'ghi'))
        how = mock.Mock()

        self.sock.shutdown(how)

        self.raw_sock.sendall.assert_called_once_with(bytearray(b'ghi'))
        self.raw_sock.shutdown.assert_called_once_with(how)

    def test_close(self):
        self.sock.buffer_writes = True

        self.sock.send(bytearray(b'jkl'))

        self.sock.close()
        self.raw_sock.sendall.assert_called_once_with(bytearray(b'jkl'))
        self.raw_sock.close.assert_called_once_with()
