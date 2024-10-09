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

from tlslite.extensions import TLSExtension, SNIExtension, NPNExtension,\
        SRPExtension, ClientCertTypeExtension, ServerCertTypeExtension,\
        TACKExtension, SupportedGroupsExtension, ECPointFormatsExtension,\
        SignatureAlgorithmsExtension, PaddingExtension, VarListExtension, \
        RenegotiationInfoExtension, ALPNExtension, StatusRequestExtension, \
        SupportedVersionsExtension, VarSeqListExtension, ListExtension, \
        ClientKeyShareExtension, KeyShareEntry, ServerKeyShareExtension, \
        CertificateStatusExtension, HRRKeyShareExtension, \
        SrvSupportedVersionsExtension, SignatureAlgorithmsCertExtension, \
        PreSharedKeyExtension, PskIdentity, SrvPreSharedKeyExtension, \
        PskKeyExchangeModesExtension, CookieExtension, VarBytesExtension, \
        HeartbeatExtension, IntExtension, RecordSizeLimitExtension
from tlslite.utils.codec import Parser, Writer
from tlslite.constants import NameType, ExtensionType, GroupName,\
        ECPointFormat, HashAlgorithm, SignatureAlgorithm, \
        CertificateStatusType, SignatureScheme, HeartbeatMode, CertificateType
from tlslite.errors import TLSInternalError

class TestTLSExtension(unittest.TestCase):
    def test___init__(self):
        tls_extension = TLSExtension()

        assert(tls_extension)
        self.assertIsNone(tls_extension.extType)
        self.assertEqual(bytearray(0), tls_extension.extData)

    def test_create(self):
        tls_extension = TLSExtension().create(1, bytearray(b'\x01\x00'))

        self.assertIsNotNone(tls_extension)
        self.assertEqual(1, tls_extension.extType)
        self.assertEqual(bytearray(b'\x01\x00'), tls_extension.extData)

    def test_new_style_create(self):
        tls_extension = TLSExtension(extType=1).create(bytearray(b'\x01\x00'))

        self.assertIsNotNone(tls_extension)
        self.assertEqual(1, tls_extension.extType)
        self.assertEqual(bytearray(b'\x01\x00'), tls_extension.extData)

    def test_new_style_create_with_keyword(self):
        tls_extension = TLSExtension(extType=1).create(data=\
                bytearray(b'\x01\x00'))

        self.assertIsNotNone(tls_extension)
        self.assertEqual(1, tls_extension.extType)
        self.assertEqual(bytearray(b'\x01\x00'), tls_extension.extData)

    def test_new_style_create_with_invalid_keyword(self):
        with self.assertRaises(TypeError):
            TLSExtension(extType=1).create(extData=bytearray(b'\x01\x00'))

    def test_old_style_create_with_keyword_args(self):
        tls_extension = TLSExtension().create(extType=1,
                                              data=bytearray(b'\x01\x00'))
        self.assertIsNotNone(tls_extension)
        self.assertEqual(1, tls_extension.extType)
        self.assertEqual(bytearray(b'\x01\x00'), tls_extension.extData)

    def test_old_style_create_with_one_keyword_arg(self):
        tls_extension = TLSExtension().create(1,
                                              data=bytearray(b'\x01\x00'))
        self.assertIsNotNone(tls_extension)
        self.assertEqual(1, tls_extension.extType)
        self.assertEqual(bytearray(b'\x01\x00'), tls_extension.extData)

    def test_old_style_create_with_invalid_keyword_name(self):
        with self.assertRaises(TypeError):
            TLSExtension().create(1,
                                  extData=bytearray(b'\x01\x00'))

    def test_old_style_create_with_duplicate_keyword_name(self):
        with self.assertRaises(TypeError):
            TLSExtension().create(1,
                                  extType=1)

    def test_create_with_too_few_args(self):
        with self.assertRaises(TypeError):
            TLSExtension().create()

    def test_create_with_too_many_args(self):
        with self.assertRaises(TypeError):
            TLSExtension().create(1, 2, 3)

    def test_write(self):
        tls_extension = TLSExtension()

        with self.assertRaises(AssertionError) as environment:
            tls_extension.write()

    def test_write_with_data(self):
        tls_extension = TLSExtension().create(44, bytearray(b'garbage'))

        self.assertEqual(bytearray(
            b'\x00\x2c' +       # type of extension - 44
            b'\x00\x07' +       # length of extension - 7 bytes
            # utf-8 encoding of "garbage"
            b'\x67\x61\x72\x62\x61\x67\x65'
            ), tls_extension.write())

    def test_parse(self):
        p = Parser(bytearray(
            b'\x00\x42' + # type of extension
            b'\x00\x01' + # length of rest of data
            b'\xff'       # value of extension
            ))
        tls_extension = TLSExtension().parse(p)

        self.assertEqual(66, tls_extension.extType)
        self.assertEqual(bytearray(b'\xff'), tls_extension.extData)

    def test_parse_with_length_long_by_one(self):
        p = Parser(bytearray(
            b'\x00\x42' + # type of extension
            b'\x00\x03' + # length of rest of data
            b'\xff\xfa'   # value of extension
            ))

        with self.assertRaises(SyntaxError) as context:
            TLSExtension().parse(p)

    def test_parse_with_sni_ext(self):
        p = Parser(bytearray(
            b'\x00\x00' +   # type of extension - SNI (0)
            b'\x00\x10' +   # length of extension - 16 bytes
            b'\x00\x0e' +   # length of array
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        tls_extension = TLSExtension().parse(p)

        self.assertIsInstance(tls_extension, SNIExtension)

        self.assertEqual(bytearray(b'example.com'), tls_extension.hostNames[0])

    def test_parse_with_SNI_server_side(self):
        p = Parser(bytearray(
            b'\x00\x00' +   # type of extension - SNI
            b'\x00\x00'     # overall length - 0 bytes
            ))

        ext = TLSExtension(server=True).parse(p)

        self.assertIsInstance(ext, SNIExtension)
        self.assertIsNone(ext.serverNames)

    def test_parse_with_SRP_ext(self):
        p = Parser(bytearray(
            b'\x00\x0c' +           # ext type - 12
            b'\x00\x09' +           # overall length
            b'\x08' +               # name length
            b'username'             # name
            ))

        ext = TLSExtension().parse(p)

        self.assertIsInstance(ext, SRPExtension)

        self.assertEqual(ext.identity, b'username')

    def test_parse_with_NPN_ext(self):
        p = Parser(bytearray(
            b'\x33\x74' +   # type of extension - NPN
            b'\x00\x09' +   # overall length
            b'\x08'     +   # first name length
            b'http/1.1'
            ))

        ext = TLSExtension().parse(p)

        self.assertIsInstance(ext, NPNExtension)

        self.assertEqual(ext.protocols, [b'http/1.1'])

    def test_parse_with_SNI_server_side(self):
        p = Parser(bytearray(
            b'\x00\x00' +   # type of extension - SNI
            b'\x00\x00'     # overall length - 0 bytes
            ))

        ext = TLSExtension(server=True).parse(p)

        self.assertIsInstance(ext, SNIExtension)
        self.assertIsNone(ext.serverNames)

    def test_parse_with_renego_info_server_side(self):
        p = Parser(bytearray(
            b'\xff\x01' +   # type of extension - renegotiation_info
            b'\x00\x01' +   # overall length
            b'\x00'         # extension length
            ))

        ext = TLSExtension(server=True).parse(p)

        # XXX not supported
        self.assertIsInstance(ext, TLSExtension)

        self.assertEqual(ext.extData, bytearray(b'\x00'))
        self.assertEqual(ext.extType, 0xff01)

    def test_parse_with_elliptic_curves(self):
        p = Parser(bytearray(
            b'\x00\x0a' +   # type of extension
            b'\x00\x08' +   # overall length
            b'\x00\x06' +   # length of array
            b'\x00\x17' +   # secp256r1
            b'\x00\x18' +   # secp384r1
            b'\x00\x19'     # secp521r1
            ))

        ext = TLSExtension().parse(p)

        self.assertIsInstance(ext, SupportedGroupsExtension)

        self.assertEqual(ext.groups, [GroupName.secp256r1,
                                      GroupName.secp384r1,
                                      GroupName.secp521r1])

    def test_parse_with_ec_point_formats(self):
        p = Parser(bytearray(
            b'\x00\x0b' +   # type of extension
            b'\x00\x02' +   # overall length
            b'\x01' +       # length of array
            b'\x00'         # type - uncompressed
            ))

        ext = TLSExtension().parse(p)

        self.assertIsInstance(ext, ECPointFormatsExtension)

        self.assertEqual(ext.formats, [ECPointFormat.uncompressed])

    def test_parse_with_signature_algorithms(self):
        p = Parser(bytearray(
            b'\x00\x0d' +   # type of extension
            b'\x00\x1c' +   # overall length
            b'\x00\x1a' +   # length of array
            b'\x04\x01' +   # SHA256+RSA
            b'\x04\x02' +   # SHA256+DSA
            b'\x04\x03' +   # SHA256+ECDSA
            b'\x05\x01' +   # SHA384+RSA
            b'\x05\x03' +   # SHA384+ECDSA
            b'\x06\x01' +   # SHA512+RSA
            b'\x06\x03' +   # SHA512+ECDSA
            b'\x03\x01' +   # SHA224+RSA
            b'\x03\x02' +   # SHA224+DSA
            b'\x03\x03' +   # SHA224+ECDSA
            b'\x02\x01' +   # SHA1+RSA
            b'\x02\x02' +   # SHA1+DSA
            b'\x02\x03'     # SHA1+ECDSA
            ))

        ext = TLSExtension().parse(p)

        self.assertIsInstance(ext, SignatureAlgorithmsExtension)

        self.assertEqual(ext.sigalgs, [(HashAlgorithm.sha256,
                                        SignatureAlgorithm.rsa),
                                       (HashAlgorithm.sha256,
                                        SignatureAlgorithm.dsa),
                                       (HashAlgorithm.sha256,
                                        SignatureAlgorithm.ecdsa),
                                       (HashAlgorithm.sha384,
                                        SignatureAlgorithm.rsa),
                                       (HashAlgorithm.sha384,
                                        SignatureAlgorithm.ecdsa),
                                       (HashAlgorithm.sha512,
                                        SignatureAlgorithm.rsa),
                                       (HashAlgorithm.sha512,
                                        SignatureAlgorithm.ecdsa),
                                       (HashAlgorithm.sha224,
                                        SignatureAlgorithm.rsa),
                                       (HashAlgorithm.sha224,
                                        SignatureAlgorithm.dsa),
                                       (HashAlgorithm.sha224,
                                        SignatureAlgorithm.ecdsa),
                                       (HashAlgorithm.sha1,
                                        SignatureAlgorithm.rsa),
                                       (HashAlgorithm.sha1,
                                        SignatureAlgorithm.dsa),
                                       (HashAlgorithm.sha1,
                                        SignatureAlgorithm.ecdsa)])

    def test_equality(self):
        a = TLSExtension().create(0, bytearray(0))
        b = SNIExtension().create()

        self.assertTrue(a == b)

    def test_equality_with_empty_array_in_sni_extension(self):
        a = TLSExtension().create(0, bytearray(b'\x00\x00'))
        b = SNIExtension().create(serverNames=[])

        self.assertTrue(a == b)

    def test_equality_with_nearly_good_object(self):
        class TestClass(object):
            def __init__(self):
                self.extType = 0

        a = TLSExtension().create(0, bytearray(b'\x00\x00'))
        b = TestClass()

        self.assertFalse(a == b)

    def test_parse_of_server_hello_extension(self):
        ext = TLSExtension(server=True)

        p = Parser(bytearray(
            b'\x00\x09' +       # extension type - cert_type (9)
            b'\x00\x01' +       # extension length - 1 byte
            b'\x01'             # certificate type - OpenGPG (1)
            ))

        ext = ext.parse(p)

        self.assertIsInstance(ext, ServerCertTypeExtension)

        self.assertEqual(1, ext.cert_type)

    def test_parse_with_encrypted_extensions_type_extension(self):
        ext = TLSExtension(encExt=True)
        parser = Parser(bytearray(b'\x00\x0a'
                                  b'\x00\x04'
                                  b'\x00\x02'
                                  b'\x00\x13'))
        ext = ext.parse(parser)

        self.assertIsInstance(ext, SupportedGroupsExtension)
        self.assertEqual(ext.groups, [GroupName.secp192r1])

    def test_parse_of_certificate_extension(self):
        ext = TLSExtension(cert=True)
        p = Parser(bytearray(
            b'\x00\x05' +  # status_request
            b'\x00\x05' +  # length
            b'\x01' +  # status_type - ocsp
            b'\x00\x00\x01' +  # ocsp response length
            b'\xba'))  # ocsp payload

        ext = ext.parse(p)

        self.assertIsInstance(ext, CertificateStatusExtension)

    def test_parse_with_client_cert_type_extension(self):
        ext = TLSExtension()

        p = Parser(bytearray(
            b'\x00\x09' +        # ext type
            b'\x00\x02' +       # ext length
            b'\x01' +           # length of array
            b'\x01'))           # type - opengpg (1)

        ext = ext.parse(p)

        self.assertIsInstance(ext, ClientCertTypeExtension)

        self.assertEqual([1], ext.certTypes)

    def test___repr__(self):
        ext = TLSExtension()
        ext = ext.create(0, bytearray(b'\x00\x00'))

        self.assertEqual("TLSExtension(extType=0, "\
                "extData=bytearray(b'\\x00\\x00'), serverType=False, "
                "encExtType=False)",
                repr(ext))

    def test_parse_with_record_size_limit_extension(self):
        ext = TLSExtension()

        p = Parser(bytearray(
            b'\x00\x1c' +  # ext type
            b'\x00\x02' +  # ext length
            b'\x01\x00'))  # ext value

        ext = ext.parse(p)

        self.assertIsInstance(ext, RecordSizeLimitExtension)
        self.assertEqual(ext.record_size_limit, 256)


class TestVarBytesExtension(unittest.TestCase):
    def setUp(self):
        self.ext = VarBytesExtension('opaque', 3, 0)

    def test_extData(self):
        self.assertEqual(bytearray(), self.ext.extData)

    def test_extData_with_data(self):
        self.ext = self.ext.create(bytearray(b'test'))

        self.assertEqual(bytearray(b'\x00\x00\x04test'), self.ext.extData)

    def test_get_non_existant_attribute(self):
        with self.assertRaises(AttributeError) as e:
            val = self.ext.example

        self.assertIn("no attribute 'example'", str(e.exception))

    def test_parse(self):
        p = Parser(bytearray())

        ext = self.ext.parse(p)

        self.assertIsInstance(ext, VarBytesExtension)
        self.assertIsNone(ext.opaque)

    def test_parse_with_data(self):
        p = Parser(bytearray(
            b'\x00\x00\x04'
            b'test'))

        ext = self.ext.parse(p)

        self.assertIsInstance(ext, VarBytesExtension)
        self.assertEqual(ext.opaque, bytearray(b'test'))

    def test_parse_with_extra_data(self):
        p = Parser(bytearray(
            b'\x00\x00\x02'
            b'test'))

        with self.assertRaises(SyntaxError):
            self.ext.parse(p)

    def test___repr__(self):
        self.assertEqual(repr(self.ext), "VarBytesExtension(opaque=None)")

    def test___repr___with_data(self):
        self.ext.opaque = bytearray(b'data')

        self.assertEqual(repr(self.ext), "VarBytesExtension(len(opaque)=4)")


class TestListExtension(unittest.TestCase):
    def setUp(self):
        self.ext = ListExtension('groups', 0)

    def test_extData(self):
        with self.assertRaises(NotImplementedError):
            _ = self.ext.extData

    def test_parse(self):
        p = Parser(bytearray(0))
        with self.assertRaises(NotImplementedError):
            self.ext.parse(p)

    def test___repr__(self):
        self.assertEqual(repr(self.ext), "ListExtension(groups=None)")

    def test___repr___with_values(self):
        self.ext.groups = [0, 1]
        self.assertEqual(repr(self.ext), "ListExtension(groups=[0, 1])")

    def test___repr___with_enum(self):
        self.ext = ListExtension('groups', 0, ECPointFormat)
        self.ext.groups = [0, 4]
        self.assertEqual(repr(self.ext),
                         "ListExtension(groups=[uncompressed, 4])")


class TestVarListExtension(unittest.TestCase):
    def setUp(self):
        self.ext = VarListExtension(1, 1, 'groups', 42)

    def test___init__(self):
        self.assertIsNotNone(self.ext)

    def test_get_attribute(self):
        self.assertIsNone(self.ext.groups)

    def test_set_attribute(self):
        self.ext.groups = [1, 2, 3]

        self.assertEqual(self.ext.groups, [1, 2, 3])

    def test_get_non_existant_attribute(self):
        with self.assertRaises(AttributeError) as e:
            val = self.ext.gruppen

        self.assertEqual(str(e.exception),
                "type object 'VarListExtension' has no attribute 'gruppen'")


class TestVarSeqListExtension(unittest.TestCase):
    def setUp(self):
        self.ext = VarSeqListExtension(2, 2, 1, 'values', 42)

    def test___init__(self):
        self.assertIsNotNone(self.ext)

    def test_get_attribute(self):
        self.assertIsNone(self.ext.values)

    def test_set_attribute(self):
        self.ext.values = [(2, 3), (3, 4), (7, 9)]

        self.assertEqual(self.ext.values, [(2, 3), (3, 4), (7, 9)])

    def test_get_non_existant_attribute(self):
        with self.assertRaises(AttributeError) as e:
            val = self.ext.value

        self.assertEqual(str(e.exception),
                "type object 'VarSeqListExtension' has no attribute 'value'")

    def test_empty_extData(self):
        self.assertEqual(self.ext.extData, bytearray())

    def test_extData(self):
        self.ext.create([(2, 3), (10, 1)])

        self.assertEqual(self.ext.extData,
                         bytearray(#b'\x00\x2a'  # ID
                                   #b'\x00\x09'  # ext length
                                   b'\x08'  # array length
                                   b'\x00\x02\x00\x03'  # first tuple
                                   b'\x00\x0a\x00\x01'))  # second tuple

    def test_parse(self):
        p = Parser(bytearray(#b'\x00\x2a'  # ID
                             #b'\x00\x09'  # ext length
                             b'\x08'  # array length
                             b'\x00\x02\x00\x03'  # first tuple
                             b'\x00\x0a\x00\x01'))  # second tuple

        self.ext = self.ext.parse(p)

        self.assertEqual(self.ext.values, [(2, 3), (10, 1)])

    def test_parse_with_trailing_data(self):
        p = Parser(bytearray(#b'\x00\x2a'  # ID
                             #b'\x00\x0a'  # ext length
                             b'\x08'  # array length
                             b'\x00\x02\x00\x03'  # first tuple
                             b'\x00\x0a\x00\x01'  # second tuple
                             b'\x00'))  # trailing byte

        with self.assertRaises(SyntaxError):
            self.ext.parse(p)

    def test_parse_empty(self):
        p = Parser(bytearray(0))

        self.ext = self.ext.parse(p)

        self.assertIsNone(self.ext.values)


class TestIntExtension(unittest.TestCase):
    def setUp(self):
        self.ext = IntExtension(2, 'value', 41)

    def test___init__(self):
        self.assertIsNotNone(self.ext)
        self.assertEqual(self.ext.extType, 41)

    def test_get_attribute(self):
        self.assertIsNone(self.ext.value)

    def test_set_attribute(self):
        self.ext.value = 22

        self.assertEqual(22, self.ext.value)

    def test_get_non_existant_attribute(self):
        with self.assertRaises(AttributeError) as e:
            val = self.ext.values

        self.assertEqual(str(e.exception),
                "type object 'IntExtension' has no attribute 'values'")

    def test_empty_extData(self):
        self.assertEqual(self.ext.extData, bytearray())

    def test_extData(self):
        self.ext.create(22)

        self.assertEqual(self.ext.extData,
                         bytearray(b'\x00\x16'))

    def test_parse_empty(self):
        parser = Parser(bytearray())

        self.ext = self.ext.parse(parser)

        self.assertIsNone(self.ext.value)

    def test_parse(self):
        parser = Parser(bytearray(b'\x01\x02'))

        self.ext = self.ext.parse(parser)

        self.assertEqual(self.ext.value, 0x0102)

    def test_parse_with_too_little_data(self):
        parser = Parser(bytearray(b'\x01'))

        with self.assertRaises(SyntaxError):
            self.ext.parse(parser)

    def test_parse_with_too_much_data(self):
        parser = Parser(bytearray(b'\x01\x02\x03'))

        with self.assertRaises(SyntaxError):
            self.ext.parse(parser)

    def test___repr__(self):
        self.ext.value = 1

        self.assertEqual("IntExtension(value=1)", repr(self.ext))

    def test___repr___with_enum(self):
        self.ext = IntExtension(2, 'value', 41, CertificateType)
        self.ext.value = 1

        self.assertEqual("IntExtension(value=openpgp)", repr(self.ext))


class TestSNIExtension(unittest.TestCase):
    def test___init__(self):
        server_name = SNIExtension()

        self.assertIsNone(server_name.serverNames)
        self.assertEqual(tuple(), server_name.hostNames)
        # properties inherited from TLSExtension:
        self.assertEqual(0, server_name.extType)
        self.assertEqual(bytearray(0), server_name.extData)

    def test_create(self):
        server_name = SNIExtension()
        server_name = server_name.create()

        self.assertIsNone(server_name.serverNames)
        self.assertEqual(tuple(), server_name.hostNames)

    def test_create_with_hostname(self):
        server_name = SNIExtension()
        server_name = server_name.create(bytearray(b'example.com'))

        self.assertEqual((bytearray(b'example.com'),), server_name.hostNames)
        self.assertEqual([SNIExtension.ServerName(
            NameType.host_name,
            bytearray(b'example.com')
            )], server_name.serverNames)

    def test_create_with_hostNames(self):
        server_name = SNIExtension()
        server_name = server_name.create(hostNames=[bytearray(b'example.com'),
            bytearray(b'www.example.com')])

        self.assertEqual((
            bytearray(b'example.com'),
            bytearray(b'www.example.com')
            ), server_name.hostNames)
        self.assertEqual([
            SNIExtension.ServerName(
                NameType.host_name,
                bytearray(b'example.com')),
            SNIExtension.ServerName(
                NameType.host_name,
                bytearray(b'www.example.com'))],
            server_name.serverNames)

    def test_create_with_serverNames(self):
        server_name = SNIExtension()
        server_name = server_name.create(serverNames=[
            SNIExtension.ServerName(1, bytearray(b'example.com')),
            SNIExtension.ServerName(4, bytearray(b'www.example.com')),
            SNIExtension.ServerName(0, bytearray(b'example.net'))])

        self.assertEqual((bytearray(b'example.net'),), server_name.hostNames)
        self.assertEqual([
            SNIExtension.ServerName(
                1, bytearray(b'example.com')),
            SNIExtension.ServerName(
                4, bytearray(b'www.example.com')),
            SNIExtension.ServerName(
                0, bytearray(b'example.net'))],
            server_name.serverNames)

    def test_hostNames(self):
        server_name = SNIExtension()
        server_name = server_name.create(serverNames=[
            SNIExtension.ServerName(0, bytearray(b'example.net')),
            SNIExtension.ServerName(1, bytearray(b'example.com')),
            SNIExtension.ServerName(4, bytearray(b'www.example.com'))
            ])

        server_name.hostNames = \
                [bytearray(b'example.com')]

        self.assertEqual((bytearray(b'example.com'),), server_name.hostNames)
        self.assertEqual([
            SNIExtension.ServerName(0, bytearray(b'example.com')),
            SNIExtension.ServerName(1, bytearray(b'example.com')),
            SNIExtension.ServerName(4, bytearray(b'www.example.com'))],
            server_name.serverNames)

    def test_hostNames_delete(self):
        server_name = SNIExtension()
        server_name = server_name.create(serverNames=[
            SNIExtension.ServerName(0, bytearray(b'example.net')),
            SNIExtension.ServerName(1, bytearray(b'example.com')),
            SNIExtension.ServerName(4, bytearray(b'www.example.com'))
            ])

        del server_name.hostNames

        self.assertEqual(tuple(), server_name.hostNames)
        self.assertEqual([
            SNIExtension.ServerName(1, bytearray(b'example.com')),
            SNIExtension.ServerName(4, bytearray(b'www.example.com'))],
            server_name.serverNames)

    def test_write(self):
        server_name = SNIExtension()
        server_name = server_name.create(bytearray(b'example.com'))

        self.assertEqual(bytearray(
            b'\x00\x0e' +   # length of array - 14 bytes
            b'\x00' +       # type of element - host_name (0)
            b'\x00\x0b' +   # length of element - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'
            ), server_name.extData)

        self.assertEqual(bytearray(
            b'\x00\x00' +   # type of extension - SNI (0)
            b'\x00\x10' +   # length of extension - 16 bytes
            b'\x00\x0e' +   # length of array - 14 bytes
            b'\x00' +       # type of element - host_name (0)
            b'\x00\x0b' +   # length of element - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'
            ), server_name.write())

    def test_write_with_multiple_hostnames(self):
        server_name = SNIExtension()
        server_name = server_name.create(hostNames=[
            bytearray(b'example.com'),
            bytearray(b'example.org')])

        self.assertEqual(bytearray(
            b'\x00\x1c' +   # lenght of array - 28 bytes
            b'\x00' +       # type of element - host_name (0)
            b'\x00\x0b' +   # length of element - 11 bytes
            # utf-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d' +
            b'\x00' +       # type of elemnt - host_name (0)
            b'\x00\x0b' +   # length of elemnet - 11 bytes
            # utf-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67'
            ), server_name.extData)

        self.assertEqual(bytearray(
            b'\x00\x00' +   # type of extension - SNI (0)
            b'\x00\x1e' +   # length of extension - 26 bytes
            b'\x00\x1c' +   # lenght of array - 24 bytes
            b'\x00' +       # type of element - host_name (0)
            b'\x00\x0b' +   # length of element - 11 bytes
            # utf-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d' +
            b'\x00' +       # type of elemnt - host_name (0)
            b'\x00\x0b' +   # length of elemnet - 11 bytes
            # utf-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67'
            ), server_name.write())

    def test_write_of_empty_extension(self):
        server_name = SNIExtension()

        self.assertEqual(bytearray(
            b'\x00\x00' +   # type of extension - SNI (0)
            b'\x00\x00'     # length of extension - 0 bytes
            ), server_name.write())

    def test_write_of_empty_list_of_names(self):
        server_name = SNIExtension()
        server_name = server_name.create(serverNames=[])

        self.assertEqual(bytearray(
            b'\x00\x00'    # length of array - 0 bytes
            ), server_name.extData)

        self.assertEqual(bytearray(
            b'\x00\x00' +  # type of extension - SNI 0
            b'\x00\x02' +  # length of extension - 2 bytes
            b'\x00\x00'    # length of array of names - 0 bytes
            ), server_name.write())

    def tes_parse_with_invalid_data(self):
        server_name = SNIExtension()

        p = Parser(bytearray(b'\x00\x01'))

        with self.assertRaises(SyntaxError):
            server_name.parse(p)

    def test_parse_of_server_side_version(self):
        server_name = SNIExtension()

        p = Parser(bytearray(0))

        server_name = server_name.parse(p)

        self.assertIsNone(server_name.serverNames)

    def test_parse_null_length_array(self):
        server_name = SNIExtension()

        p = Parser(bytearray(b'\x00\x00'))

        server_name = server_name.parse(p)

        self.assertEqual([], server_name.serverNames)

    def test_parse_with_host_name(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x0e' +   # length of array
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        server_name = server_name.parse(p)

        self.assertEqual(bytearray(b'example.com'), server_name.hostNames[0])
        self.assertEqual(tuple([bytearray(b'example.com')]),
                server_name.hostNames)

    def test_parse_with_multiple_hostNames(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x1c' +   # length of array - 28 bytes
            b'\x0a' +       # type of entry - unassigned (10)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67' +
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        server_name = server_name.parse(p)

        self.assertEqual(bytearray(b'example.com'), server_name.hostNames[0])
        self.assertEqual(tuple([bytearray(b'example.com')]),
                server_name.hostNames)

        SN = SNIExtension.ServerName

        self.assertEqual([
            SN(10, bytearray(b'example.org')),
            SN(0, bytearray(b'example.com'))
            ], server_name.serverNames)

    def test_parse_with_array_length_long_by_one(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x0f' +   # length of array (one too long)
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

    def test_parse_with_array_length_short_by_one(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x0d' +   # length of array (one too short)
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

    def test_parse_with_name_length_long_by_one(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x1c' +   # length of array - 28 bytes
            b'\x0a' +       # type of entry - unassigned (10)
            b'\x00\x0c' +   # length of name - 12 bytes (long by one)
            # UTF-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67' +
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x1c' +   # length of array - 28 bytes
            b'\x0a' +       # type of entry - unassigned (10)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67' +
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0c' +   # length of name - 12 bytes (long by one)
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

    def test_parse_with_name_length_short_by_one(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x1c' +   # length of array - 28 bytes
            b'\x0a' +       # type of entry - unassigned (10)
            b'\x00\x0a' +   # length of name - 10 bytes (short by one)
            # UTF-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67' +
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x1c' +   # length of array - 28 bytes
            b'\x0a' +       # type of entry - unassigned (10)
            b'\x00\x0b' +   # length of name - 11 bytes
            # UTF-8 encoding of example.org
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x6f\x72\x67' +
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x0a' +   # length of name - 10 bytes (short by one)
            # UTF-8 encoding of example.com
            b'\x65\x78\x61\x6d\x70\x6c\x65\x2e\x63\x6f\x6d'))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

    def test_parse_with_trailing_data(self):
        server_name = SNIExtension()

        p = Parser(bytearray(
            b'\x00\x04' +   # length of array - 4 bytes
            b'\x00' +       # type of entry - host_name (0)
            b'\x00\x01' +   # length of name - 1 byte
            b'e' +          # entry
            b'x'            # trailing data
            ))

        with self.assertRaises(SyntaxError):
            server_name = server_name.parse(p)

    def test___repr__(self):
        server_name = SNIExtension()
        server_name = server_name.create(
                serverNames=[
                    SNIExtension.ServerName(0, bytearray(b'example.com')),
                    SNIExtension.ServerName(1, bytearray(b'\x04\x01'))])

        self.assertEqual("SNIExtension(serverNames=["\
                "ServerName(name_type=0, name=bytearray(b'example.com')), "\
                "ServerName(name_type=1, name=bytearray(b'\\x04\\x01'))])",
                repr(server_name))

class TestClientCertTypeExtension(unittest.TestCase):
    def test___init___(self):
        cert_type = ClientCertTypeExtension()

        self.assertEqual(9, cert_type.extType)
        self.assertEqual(bytearray(0), cert_type.extData)
        self.assertIsNone(cert_type.certTypes)

    def test_create(self):
        cert_type = ClientCertTypeExtension()
        cert_type = cert_type.create(None)

        self.assertEqual(9, cert_type.extType)
        self.assertEqual(bytearray(0), cert_type.extData)
        self.assertIsNone(cert_type.certTypes)

    def test_create_with_empty_list(self):
        cert_type = ClientCertTypeExtension()
        cert_type = cert_type.create([])

        self.assertEqual(bytearray(b'\x00'), cert_type.extData)
        self.assertEqual([], cert_type.certTypes)

    def test_create_with_list(self):
        cert_type = ClientCertTypeExtension()
        cert_type = cert_type.create([0])

        self.assertEqual(bytearray(b'\x01\x00'), cert_type.extData)
        self.assertEqual([0], cert_type.certTypes)

    def test_write(self):
        cert_type = ClientCertTypeExtension()
        cert_type = cert_type.create([0, 1])

        self.assertEqual(bytearray(
            b'\x00\x09' +
            b'\x00\x03' +
            b'\x02' +
            b'\x00\x01'), cert_type.write())

    def test_parse(self):
        cert_type = ClientCertTypeExtension()

        p = Parser(bytearray(b'\x00'))

        cert_type = cert_type.parse(p)

        self.assertEqual(9, cert_type.extType)
        self.assertEqual([], cert_type.certTypes)

    def test_parse_with_list(self):
        cert_type = ClientCertTypeExtension()

        p = Parser(bytearray(b'\x02\x01\x00'))

        cert_type = cert_type.parse(p)

        self.assertEqual([1, 0], cert_type.certTypes)

    def test_parse_with_length_long_by_one(self):
        cert_type = ClientCertTypeExtension()

        p = Parser(bytearray(b'\x03\x01\x00'))

        with self.assertRaises(SyntaxError):
            cert_type.parse(p)

    def test___repr__(self):
        cert_type = ClientCertTypeExtension()
        cert_type = cert_type.create([0, 1, 99])

        self.assertEqual(
            "ClientCertTypeExtension(certTypes=[x509, openpgp, 99])",
            repr(cert_type))


class TestServerCertTypeExtension(unittest.TestCase):
    def test___init__(self):
        cert_type = ServerCertTypeExtension()

        self.assertEqual(9, cert_type.extType)
        self.assertEqual(bytearray(0), cert_type.extData)
        self.assertIsNone(cert_type.cert_type)

    def test_create(self):
        cert_type = ServerCertTypeExtension().create(0)

        self.assertEqual(9, cert_type.extType)
        self.assertEqual(bytearray(b'\x00'), cert_type.extData)
        self.assertEqual(0, cert_type.cert_type)

    def test_parse(self):
        p = Parser(bytearray(
            b'\x00'             # certificate type - X.509 (0)
            ))

        cert_type = ServerCertTypeExtension().parse(p)

        self.assertEqual(0, cert_type.cert_type)

    def test_parse_with_no_data(self):
        p = Parser(bytearray(0))

        cert_type = ServerCertTypeExtension()

        with self.assertRaises(SyntaxError):
            cert_type.parse(p)

    def test_parse_with_too_much_data(self):
        p = Parser(bytearray(b'\x00\x00'))

        cert_type = ServerCertTypeExtension()

        with self.assertRaises(SyntaxError):
            cert_type.parse(p)

    def test_write(self):
        cert_type = ServerCertTypeExtension().create(1)

        self.assertEqual(bytearray(
            b'\x00\x09' +       # extension type - cert_type (9)
            b'\x00\x01' +       # extension length - 1 byte
            b'\x01'             # selected certificate type - OpenPGP (1)
            ), cert_type.write())

    def test___repr__(self):
        cert_type = ServerCertTypeExtension().create(1)

        self.assertEqual("ServerCertTypeExtension(cert_type=openpgp)",
                repr(cert_type))

class TestSRPExtension(unittest.TestCase):
    def test___init___(self):
        srp_extension = SRPExtension()

        self.assertIsNone(srp_extension.identity)
        self.assertEqual(12, srp_extension.extType)
        self.assertEqual(bytearray(0), srp_extension.extData)

    def test_create(self):
        srp_extension = SRPExtension()
        srp_extension = srp_extension.create()

        self.assertIsNone(srp_extension.identity)
        self.assertEqual(12, srp_extension.extType)
        self.assertEqual(bytearray(0), srp_extension.extData)

    def test_create_with_name(self):
        srp_extension = SRPExtension()
        srp_extension = srp_extension.create(bytearray(b'username'))

        self.assertEqual(bytearray(b'username'), srp_extension.identity)
        self.assertEqual(bytearray(
            b'\x08' + # length of string - 8 bytes
            b'username'), srp_extension.extData)

    def test_create_with_too_long_name(self):
        srp_extension = SRPExtension()

        with self.assertRaises(ValueError):
            srp_extension = srp_extension.create(bytearray(b'a'*256))

    def test_write(self):
        srp_extension = SRPExtension()
        srp_extension = srp_extension.create(bytearray(b'username'))

        self.assertEqual(bytearray(
            b'\x00\x0c' +   # type of extension - SRP (12)
            b'\x00\x09' +   # length of extension - 9 bytes
            b'\x08' +       # length of encoded name
            b'username'), srp_extension.write())

    def test_parse(self):
        srp_extension = SRPExtension()
        p = Parser(bytearray(b'\x00'))

        srp_extension = srp_extension.parse(p)

        self.assertEqual(bytearray(0), srp_extension.identity)

    def test_parse(self):
        srp_extension = SRPExtension()
        p = Parser(bytearray(
            b'\x08' +
            b'username'))

        srp_extension = srp_extension.parse(p)

        self.assertEqual(bytearray(b'username'),
                srp_extension.identity)

    def test_parse_with_length_long_by_one(self):
        srp_extension = SRPExtension()
        p = Parser(bytearray(
            b'\x09' +
            b'username'))

        with self.assertRaises(SyntaxError):
            srp_extension = srp_extension.parse(p)

    def test___repr__(self):
        srp_extension = SRPExtension()
        srp_extension = srp_extension.create(bytearray(b'user'))

        self.assertEqual("SRPExtension(identity=bytearray(b'user'))",
                repr(srp_extension))

class TestNPNExtension(unittest.TestCase):
    def test___init___(self):
        npn_extension = NPNExtension()

        self.assertIsNone(npn_extension.protocols)
        self.assertEqual(13172, npn_extension.extType)
        self.assertEqual(bytearray(0), npn_extension.extData)

    def test_create(self):
        npn_extension = NPNExtension()
        npn_extension = npn_extension.create()

        self.assertIsNone(npn_extension.protocols)
        self.assertEqual(13172, npn_extension.extType)
        self.assertEqual(bytearray(0), npn_extension.extData)

    def test_create_with_list_of_protocols(self):
        npn_extension = NPNExtension()
        npn_extension = npn_extension.create([
            bytearray(b'http/1.1'),
            bytearray(b'spdy/3')])

        self.assertEqual([
            bytearray(b'http/1.1'),
            bytearray(b'spdy/3')], npn_extension.protocols)
        self.assertEqual(bytearray(
            b'\x08' +   # length of name of protocol
            # utf-8 encoding of "http/1.1"
            b'\x68\x74\x74\x70\x2f\x31\x2e\x31' +
            b'\x06' +   # length of name of protocol
            # utf-8 encoding of "http/1.1"
            b'\x73\x70\x64\x79\x2f\x33'
            ), npn_extension.extData)

    def test_write(self):
        npn_extension = NPNExtension().create()

        self.assertEqual(bytearray(
            b'\x33\x74' +   # type of extension - NPN
            b'\x00\x00'     # length of extension
            ), npn_extension.write())

    def test_write_with_list(self):
        npn_extension = NPNExtension()
        npn_extensnio = npn_extension.create([
            bytearray(b'http/1.1'),
            bytearray(b'spdy/3')])

        self.assertEqual(bytearray(
            b'\x33\x74' +   # type of extension - NPN
            b'\x00\x10' +   # length of extension
            b'\x08' +       # length of name of protocol
            # utf-8 encoding of "http/1.1"
            b'\x68\x74\x74\x70\x2f\x31\x2e\x31' +
            b'\x06' +       # length of name of protocol
            # utf-8 encoding of "spdy/3"
            b'\x73\x70\x64\x79\x2f\x33'
            ), npn_extension.write())

    def test_parse(self):
        npn_extension = NPNExtension()

        p = Parser(bytearray(0))

        npn_extension = npn_extension.parse(p)

        self.assertEqual(bytearray(0), npn_extension.extData)
        self.assertEqual([], npn_extension.protocols)

    def test_parse_with_procotol(self):
        npn_extension = NPNExtension()

        p = Parser(bytearray(
            b'\x08' +   # length of name
            b'\x68\x74\x74\x70\x2f\x31\x2e\x31'))

        npn_extension = npn_extension.parse(p)

        self.assertEqual([bytearray(b'http/1.1')], npn_extension.protocols)

    def test_parse_with_protocol_length_short_by_one(self):
        npn_extension = NPNExtension()

        p = Parser(bytearray(
            b'\x07' +   # length of name - 7 (short by one)
            b'\x68\x74\x74\x70\x2f\x31\x2e\x31'))

        with self.assertRaises(SyntaxError):
            npn_extension.parse(p)

    def test_parse_with_protocol_length_long_by_one(self):
        npn_extension = NPNExtension()

        p = Parser(bytearray(
            b'\x09' +   # length of name - 9 (short by one)
            b'\x68\x74\x74\x70\x2f\x31\x2e\x31'))

        with self.assertRaises(SyntaxError):
            npn_extension.parse(p)

    def test___repr__(self):
        npn_extension = NPNExtension().create([bytearray(b'http/1.1')])

        self.assertEqual("NPNExtension(protocols=[bytearray(b'http/1.1')])",
                repr(npn_extension))

class TestTACKExtension(unittest.TestCase):
    def test___init__(self):
        tack_ext = TACKExtension()

        self.assertEqual([], tack_ext.tacks)
        self.assertEqual(0, tack_ext.activation_flags)
        self.assertEqual(62208, tack_ext.extType)
        self.assertEqual(bytearray(b'\x00\x00\x00'), tack_ext.extData)

    def test_create(self):
        tack_ext = TACKExtension().create([], 1)

        self.assertEqual([], tack_ext.tacks)
        self.assertEqual(1, tack_ext.activation_flags)

    def test_tack___init__(self):
        tack = TACKExtension.TACK()

        self.assertEqual(bytearray(64), tack.public_key)
        self.assertEqual(0, tack.min_generation)
        self.assertEqual(0, tack.generation)
        self.assertEqual(0, tack.expiration)
        self.assertEqual(bytearray(32), tack.target_hash)
        self.assertEqual(bytearray(64), tack.signature)

    def test_tack_create(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*64))

        self.assertEqual(bytearray(b'\x01'*64), tack.public_key)
        self.assertEqual(2, tack.min_generation)
        self.assertEqual(3, tack.generation)
        self.assertEqual(4, tack.expiration)
        self.assertEqual(bytearray(b'\x05'*32), tack.target_hash)
        self.assertEqual(bytearray(b'\x06'*64), tack.signature)

    def test_tack_write(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*64))

        self.assertEqual(bytearray(
            b'\x01'*64 +            # public_key
            b'\x02' +               # min_generation
            b'\x03' +               # generation
            b'\x00\x00\x00\x04' +   # expiration
            b'\x05'*32 +            # target_hash
            b'\x06'*64)             # signature
            , tack.write())

    def test_tack_write_with_bad_length_public_key(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*65),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*64))

        with self.assertRaises(TLSInternalError):
            tack.write()

    def test_tack_write_with_bad_length_target_hash(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*33),
                bytearray(b'\x06'*64))

        with self.assertRaises(TLSInternalError):
            tack.write()

    def test_tack_write_with_bad_length_signature(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*65))

        with self.assertRaises(TLSInternalError):
            tack.write()

    def test_tack_parse(self):
        p = Parser(bytearray(
            b'\x01'*64 +            # public_key
            b'\x02' +               # min_generation
            b'\x03' +               # generation
            b'\x00\x00\x00\x04' +   # expiration
            b'\x05'*32 +            # target_hash
            b'\x06'*64))            # signature

        tack = TACKExtension.TACK()

        tack = tack.parse(p)

        self.assertEqual(bytearray(b'\x01'*64), tack.public_key)
        self.assertEqual(2, tack.min_generation)
        self.assertEqual(3, tack.generation)
        self.assertEqual(4, tack.expiration)
        self.assertEqual(bytearray(b'\x05'*32), tack.target_hash)
        self.assertEqual(bytearray(b'\x06'*64), tack.signature)

    def test_tack___eq__(self):
        a = TACKExtension.TACK()
        b = TACKExtension.TACK()

        self.assertTrue(a == b)
        self.assertFalse(a == None)
        self.assertFalse(a == "test")

    def test_tack___eq___with_different_tacks(self):
        a = TACKExtension.TACK()
        b = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*64))

        self.assertFalse(a == b)

    def test_extData(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*64))

        tack_ext = TACKExtension().create([tack], 1)

        self.assertEqual(bytearray(
            b'\x00\xa6' +           # length
            b'\x01'*64 +            # public_key
            b'\x02' +               # min_generation
            b'\x03' +               # generation
            b'\x00\x00\x00\x04' +   # expiration
            b'\x05'*32 +            # target_hash
            b'\x06'*64 +            # signature
            b'\x01'                 # activation flag
            ), tack_ext.extData)

    def test_parse(self):
        p = Parser(bytearray(3))

        tack_ext = TACKExtension().parse(p)

        self.assertEqual([], tack_ext.tacks)
        self.assertEqual(0, tack_ext.activation_flags)

    def test_parse_with_a_tack(self):
        p = Parser(bytearray(
            b'\x00\xa6' +           # length of array (166 bytes)
            b'\x01'*64 +            # public_key
            b'\x02' +               # min_generation
            b'\x03' +               # generation
            b'\x00\x00\x00\x04' +   # expiration
            b'\x05'*32 +            # target_hash
            b'\x06'*64 +            # signature
            b'\x01'))               # activation_flags

        tack_ext = TACKExtension().parse(p)

        tack = TACKExtension.TACK().create(
                bytearray(b'\x01'*64),
                2,
                3,
                4,
                bytearray(b'\x05'*32),
                bytearray(b'\x06'*64))
        self.assertEqual([tack], tack_ext.tacks)
        self.assertEqual(1, tack_ext.activation_flags)

    def test___repr__(self):
        tack = TACKExtension.TACK().create(
                bytearray(b'\x00'),
                1,
                2,
                3,
                bytearray(b'\x04'),
                bytearray(b'\x05'))
        tack_ext = TACKExtension().create([tack], 1)
        self.maxDiff = None
        self.assertEqual("TACKExtension(activation_flags=1, tacks=["\
                "TACK(public_key=bytearray(b'\\x00'), min_generation=1, "\
                "generation=2, expiration=3, target_hash=bytearray(b'\\x04'), "\
                "signature=bytearray(b'\\x05'))"\
                "])",
                repr(tack_ext))

class TestSupportedGroups(unittest.TestCase):
    def test___init__(self):
        ext = SupportedGroupsExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.groups)

    def test_write(self):
        ext = SupportedGroupsExtension()
        ext.create([19, 21])

        self.assertEqual(bytearray(
            b'\x00\x0A' +           # type of extension - 10
            b'\x00\x06' +           # overall length of extension
            b'\x00\x04' +           # length of extension list array
            b'\x00\x13' +           # secp192r1
            b'\x00\x15'             # secp224r1
            ), ext.write())

    def test_write_empty(self):
        ext = SupportedGroupsExtension()

        self.assertEqual(bytearray(b'\x00\x0A\x00\x00'), ext.write())

    def test_parse(self):
        parser = Parser(bytearray(
            b'\x00\x04' +           # length of extension list array
            b'\x00\x13' +           # secp192r1
            b'\x00\x15'             # secp224r1
            ))

        ext = SupportedGroupsExtension().parse(parser)

        self.assertEqual(ext.extType, ExtensionType.supported_groups)
        self.assertEqual(ext.groups,
                         [GroupName.secp192r1, GroupName.secp224r1])
        for group in ext.groups:
            self.assertTrue(group in GroupName.allEC)
            self.assertFalse(group in GroupName.allFF)

    def test_parse_with_empty_data(self):
        parser = Parser(bytearray())

        ext = SupportedGroupsExtension().parse(parser)

        self.assertEqual(ext.extType, ExtensionType.supported_groups)
        self.assertIsNone(ext.groups)

    def test_parse_with_trailing_data(self):
        parser = Parser(bytearray(
            b'\x00\x04' +           # length of extension list array
            b'\x00\x13' +           # secp192r1
            b'\x00\x15' +           # secp224r1
            b'\x00'                 # trailing byte
            ))

        with self.assertRaises(SyntaxError):
            SupportedGroupsExtension().parse(parser)

    def test_parse_with_empty_array(self):
        parser = Parser(bytearray(2))

        ext = SupportedGroupsExtension().parse(parser)

        self.assertEqual([], ext.groups)

    def test_parse_with_invalid_data(self):
        parser = Parser(bytearray(b'\x00\x01\x00'))

        ext = SupportedGroupsExtension()

        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test___repr__(self):
        ext = SupportedGroupsExtension().create([GroupName.secp256r1, 200])
        self.assertEqual(
            "SupportedGroupsExtension(groups=[secp256r1, 200])",
            repr(ext))


class TestECPointFormatsExtension(unittest.TestCase):
    def test___init__(self):
        ext = ECPointFormatsExtension()

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extData, bytearray(0))
        self.assertEqual(ext.extType, 11)

    def test_write(self):
        ext = ECPointFormatsExtension()
        ext.create([ECPointFormat.ansiX962_compressed_prime])

        self.assertEqual(bytearray(
            b'\x00\x0b' +           # type of extension
            b'\x00\x02' +           # overall length
            b'\x01' +               # length of list
            b'\x01'), ext.write())

    def test_parse(self):
        parser = Parser(bytearray(b'\x01\x00'))

        ext = ECPointFormatsExtension()
        self.assertIsNone(ext.formats)
        ext.parse(parser)
        self.assertEqual(ext.formats, [ECPointFormat.uncompressed])

    def test_parse_with_empty_data(self):
        parser = Parser(bytearray(0))

        ext = ECPointFormatsExtension()

        ext.parse(parser)

        self.assertIsNone(ext.formats)

    def test___repr__(self):
        ext = ECPointFormatsExtension().create([ECPointFormat.uncompressed,
                                                14])
        self.assertEqual(
            "ECPointFormatsExtension(formats=[uncompressed, 14])",
            repr(ext))


class TestSignatureAlgorithmsExtension(unittest.TestCase):
    def test__init__(self):
        ext = SignatureAlgorithmsExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.sigalgs)
        self.assertEqual(ext.extType, 13)
        self.assertEqual(ext.extData, bytearray(0))

    def test_write(self):
        ext = SignatureAlgorithmsExtension()
        ext.create([(HashAlgorithm.sha1, SignatureAlgorithm.rsa),
                    (HashAlgorithm.sha256, SignatureAlgorithm.rsa)])

        self.assertEqual(bytearray(
            b'\x00\x0d' +           # type of extension
            b'\x00\x06' +           # overall length of extension
            b'\x00\x04' +           # array length
            b'\x02\x01' +           # SHA1+RSA
            b'\x04\x01'             # SHA256+RSA
            ), ext.write())

    def test_parse_with_empty_data(self):
        parser = Parser(bytearray(0))

        ext = SignatureAlgorithmsExtension()

        ext.parse(parser)

        self.assertIsNone(ext.sigalgs)

    def test_parse_with_extra_data_at_end(self):
        parser = Parser(bytearray(
            b'\x00\x02' +           # array length
            b'\x04\x01' +           # SHA256+RSA
            b'\xff\xff'))           # padding

        ext = SignatureAlgorithmsExtension()

        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test___repr__(self):
        ext = SignatureAlgorithmsExtension().create([(HashAlgorithm.sha1,
                                                      SignatureAlgorithm.rsa),
                                                     (HashAlgorithm.sha256,
                                                      SignatureAlgorithm.rsa),
                                                     (HashAlgorithm.sha384,
                                                      SignatureAlgorithm.dsa)])

        self.assertEqual(repr(ext),
                "SignatureAlgorithmsExtension("
                "sigalgs=[rsa_pkcs1_sha1, rsa_pkcs1_sha256, dsa_sha384])")

    def test___repr___with_none(self):
        ext = SignatureAlgorithmsExtension()

        self.assertEqual(repr(ext), "SignatureAlgorithmsExtension("
                "sigalgs=None)")


class TestSignatureAlgorithmsCertExtension(unittest.TestCase):
    def test___init__(self):
        ext = SignatureAlgorithmsCertExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.sigalgs)
        self.assertEqual(ext.extType, 50)
        self.assertEqual(ext.extData, bytearray())

    def test_write(self):
        ext = SignatureAlgorithmsCertExtension()
        ext.create([SignatureScheme.rsa_pss_pss_sha384,
                    SignatureScheme.rsa_pkcs1_sha1])

        self.assertEqual(bytearray(
            b'\x00\x32' +  # type
            b'\x00\x06' +  # overall length
            b'\x00\x04' +  # lenth of array
            b'\x08\x0a' +  # pss+sha384
            b'\x02\x01'),  # pkcs1+sha1
            ext.write())

    def test___repr__(self):
        algs = [SignatureScheme.rsa_pkcs1_sha1,
                SignatureScheme.rsa_pss_rsae_sha512,
                SignatureScheme.rsa_pss_pss_sha256,
                SignatureScheme.dsa_sha384]
        ext = SignatureAlgorithmsCertExtension().create(algs)

        self.assertEqual(repr(ext),
                "SignatureAlgorithmsCertExtension(sigalgs=["
                "rsa_pkcs1_sha1, rsa_pss_rsae_sha512, rsa_pss_pss_sha256, "
                "dsa_sha384])")

    def test___repr___with_legacy_name(self):
        algs = [SignatureScheme.rsa_pss_sha256]
        ext = SignatureAlgorithmsCertExtension().create(algs)

        self.assertEqual(repr(ext),
                "SignatureAlgorithmsCertExtension(sigalgs=["
                "rsa_pss_rsae_sha256])")

    def test___repr___with_none(self):
        ext = SignatureAlgorithmsCertExtension()

        self.assertEqual(repr(ext),
                "SignatureAlgorithmsCertExtension(sigalgs=None)")


class TestPaddingExtension(unittest.TestCase):
    def test__init__(self):
        ext = PaddingExtension()

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extType, 21)
        self.assertEqual(ext.paddingData, bytearray(0))

    def test_create(self):
        ext = PaddingExtension()
        ext.create(3)

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extType, 21)
        self.assertEqual(ext.paddingData, bytearray(b'\x00\x00\x00'))

    def test_write(self):
        ext = PaddingExtension()
        ext.create(6)

        self.assertEqual(bytearray(
            b'\x00\x15' +           # type of extension
            b'\x00\x06' +           # overall length of extension
            b'\x00\x00' +           # 1st and 2nd null byte
            b'\x00\x00' +           # 3rd and 4th null byte
            b'\x00\x00'             # 5th and 6th null byte
            ), ext.write())

    def test_parse_with_empty_data(self):
        parser = Parser(bytearray(0))

        ext = PaddingExtension()

        ext.parse(parser)

        self.assertEqual(bytearray(b''), ext.paddingData)

    def test_parse_with_nonempty_data(self):
        parser = Parser(bytearray(
            b'\x00\x00' +           # 1st and 2nd null byte
            b'\x00\x00'))           # 3rd and 4th null byte

        ext = PaddingExtension()

        ext.parse(parser)

        self.assertEqual(bytearray(b'\x00\x00\x00\x00'), ext.paddingData)

class TestRenegotiationInfoExtension(unittest.TestCase):
    def test__init__(self):
        ext = RenegotiationInfoExtension()

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extType, 0xff01)
        self.assertIsNone(ext.renegotiated_connection)

    def test_create(self):
        ext = RenegotiationInfoExtension()
        ext = ext.create(bytearray(0))

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extType, 0xff01)
        self.assertEqual(ext.renegotiated_connection, bytearray(0))

    def test_write(self):
        ext = RenegotiationInfoExtension()
        ext.create(bytearray(range(0, 6)))

        self.assertEqual(bytearray(
            b'\xff\x01'
            b'\x00\x07'
            b'\x06'
            b'\x00\x01\x02\x03\x04\x05'),
            ext.write())

    def test_write_with_empty_data(self):
        ext = RenegotiationInfoExtension()

        self.assertEqual(bytearray(
            b'\xff\x01'
            b'\x00\x00'),
            ext.write())

    def test_parse_with_empty_data(self):
        parser = Parser(bytearray(0))

        ext = RenegotiationInfoExtension()
        ext.parse(parser)

        self.assertIsNone(ext.renegotiated_connection)

    def test_parse_with_empty_array(self):
        parser = Parser(bytearray(b'\x00'))

        ext = RenegotiationInfoExtension()
        ext.parse(parser)

        self.assertEqual(ext.renegotiated_connection, bytearray(0))

    def test_parse_with_data(self):
        parser = Parser(bytearray(b'\x03abc'))

        ext = RenegotiationInfoExtension()
        ext.parse(parser)

        self.assertEqual(ext.renegotiated_connection, bytearray(b'abc'))


class TestAPLNExtension(unittest.TestCase):
    def setUp(self):
        self.ext = ALPNExtension()

    def test___init__(self):
        self.assertIsNotNone(self.ext)
        self.assertEqual(self.ext.extType, 16)
        self.assertEqual(self.ext.extData, bytearray())
        self.assertIsNone(self.ext.protocol_names)

    def test___repr__(self):
        self.assertEqual("ALPNExtension(protocol_names=None)",
                         repr(self.ext))

    def test_create(self):
        self.ext.create([bytearray(b'http/1.1'),
                         bytearray(b'spdy/1')])
        self.assertEqual(self.ext.protocol_names,
                         [bytearray(b'http/1.1'),
                          bytearray(b'spdy/1')])

    def test___repr___with_values(self):
        self.ext.create([bytearray(b'http/1.1'),
                         bytearray(b'spdy/1')])

        self.assertEqual("ALPNExtension(protocol_names="
                         "[bytearray(b'http/1.1'), bytearray(b'spdy/1')])",
                         repr(self.ext))

    def test_extData_with_empty_array(self):
        self.ext.create([])

        self.assertEqual(self.ext.extData, bytearray(b'\x00\x00'))

    def test_extData_with_empty_names(self):
        self.ext.create([bytearray(), bytearray()])

        self.assertEqual(self.ext.extData, bytearray(b'\x00\x02\x00\x00'))

    def test_extData_with_names(self):
        self.ext.create([bytearray(b'http/1.1'), bytearray(b'spdy/1')])

        self.assertEqual(self.ext.extData,
                         bytearray(b'\x00\x10'
                                   b'\x08http/1.1'
                                   b'\x06spdy/1'))

    def test_parse_with_empty_data(self):
        parser = Parser(bytearray(b''))

        with self.assertRaises(SyntaxError):
            self.ext.parse(parser)

    def test_parse_with_empty_array(self):
        parser = Parser(bytearray(b'\x00\x00'))

        self.ext.parse(parser)

        self.assertEqual(self.ext.protocol_names, [])

    def test_parse_with_too_little_data(self):
        parser = Parser(bytearray(b'\x00\x10'
                                  b'\x08http/1.1'))

        with self.assertRaises(SyntaxError):
            self.ext.parse(parser)

    def test_parse_with_too_much_data(self):
        parser = Parser(bytearray(b'\x00\x10'
                                  b'\x08http/1.1'
                                  b'\x06spdy/1'
                                  b'\x06spdy/2'))

        with self.assertRaises(SyntaxError):
            self.ext.parse(parser)

    def test_parse_with_values(self):
        parser = Parser(bytearray(b'\x00\x10'
                                  b'\x08http/1.1'
                                  b'\x06spdy/1'))

        ext = self.ext.parse(parser)

        self.assertIs(ext, self.ext)

        self.assertEqual(ext.protocol_names, [bytearray(b'http/1.1'),
                                              bytearray(b'spdy/1')])

    def test_parse_from_TLSExtension(self):
        ext = TLSExtension()

        parser = Parser(bytearray(b'\x00\x10\x00\x12'
                                  b'\x00\x10'
                                  b'\x08http/1.1'
                                  b'\x06spdy/1'))

        ext2 = ext.parse(parser)
        self.assertIsInstance(ext2, ALPNExtension)
        self.assertEqual(ext2.protocol_names, [bytearray(b'http/1.1'),
                                               bytearray(b'spdy/1')])


class TestStatusRequestExtension(unittest.TestCase):
    def setUp(self):
        self.ext = StatusRequestExtension()

    def test___init__(self):
        self.assertIsNotNone(self.ext)
        self.assertEqual(self.ext.extType, 5)
        self.assertEqual(self.ext.extData, bytearray())
        self.assertIsNone(self.ext.status_type)
        self.assertEqual(self.ext.responder_id_list, [])
        self.assertEqual(self.ext.request_extensions, bytearray())

    def test__repr__(self):
        self.assertEqual("StatusRequestExtension(status_type=None, "
                         "responder_id_list=[], "
                         "request_extensions=bytearray(b''))", repr(self.ext))

    def test_create(self):
        e = self.ext.create()
        self.assertIs(e, self.ext)
        self.assertEqual(e.status_type, 1)
        self.assertEqual(e.responder_id_list, [])
        self.assertEqual(e.request_extensions, bytearray())

    def test_extData_with_default(self):
        self.ext.create()
        self.assertEqual(self.ext.extData,
                         bytearray(b'\x01\x00\x00\x00\x00'))

    def test_extData_with_data(self):
        self.ext.create(status_type=15,
                        responder_id_list=[bytearray(b'abba'),
                                           bytearray(b'xxx')],
                        request_extensions=bytearray(b'\x08\x09'))

        self.assertEqual(self.ext.extData,
                         bytearray(b'\x0f'
                                   b'\x00\x0b'
                                   b'\x00\x04abba'
                                   b'\x00\x03xxx'
                                   b'\x00\x02'
                                   b'\x08\x09'))


    def test_parse_empty(self):
        parser = Parser(bytearray())

        e = self.ext.parse(parser)
        self.assertIs(e, self.ext)

        self.assertIsNone(e.status_type)
        self.assertEqual(e.responder_id_list, [])
        self.assertEqual(e.request_extensions, bytearray())

    def test_parse_typical(self):
        parser = Parser(bytearray(b'\x01\x00\x00\x00\x00'))

        e = self.ext.parse(parser)
        self.assertIs(e, self.ext)

        self.assertEqual(self.ext.status_type, CertificateStatusType.ocsp)
        self.assertEqual(self.ext.responder_id_list, [])
        self.assertEqual(self.ext.request_extensions, bytearray())

    def test_parse_with_values(self):
        parser = Parser(bytearray(b'\x0f'
                                  b'\x00\x0b'
                                  b'\x00\x04abba'
                                  b'\x00\x03xxx'
                                  b'\x00\x02'
                                  b'\x08\x09'))

        self.ext.parse(parser)

        self.assertEqual(self.ext.status_type, 15)
        self.assertEqual(self.ext.responder_id_list, [bytearray(b'abba'),
                                                      bytearray(b'xxx')])
        self.assertEqual(self.ext.request_extensions, bytearray(b'\x08\x09'))

    def test_parse_with_trailing_data(self):
        parser = Parser(bytearray(b'\x0f'
                                  b'\x00\x0b'
                                  b'\x00\x04abba'
                                  b'\x00\x03xxx'
                                  b'\x00\x02'
                                  b'\x08\x09'
                                  b'\x00'))

        with self.assertRaises(SyntaxError):
            self.ext.parse(parser)


class TestSupportedVersionsExtension(unittest.TestCase):
    def test___init__(self):
        ext = SupportedVersionsExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.versions)
        self.assertEqual(bytearray(0), ext.extData)
        self.assertEqual(43, ext.extType)

    def test_create(self):
        ext = SupportedVersionsExtension()

        ext = ext.create([(3, 1), (3, 2)])

        self.assertEqual([(3, 1), (3, 2)], ext.versions)

    def test_extData(self):
        ext = SupportedVersionsExtension()

        ext = ext.create([(3, 3), (3, 4)])

        self.assertEqual(ext.extData, bytearray(b'\x04'  # overall length
                                                b'\x03\x03'  # first item
                                                b'\x03\x04'))  # second item

    def test_parse(self):
        ext = TLSExtension()

        p = Parser(bytearray(
            b'\x00\x2b'  # type of ext
            b'\x00\x05'  # length
            b'\x04'      # length of array inside
            b'\x03\x03'  # first item
            b'\x03\x04'))  # second item

        ext = ext.parse(p)

        self.assertIsInstance(ext, SupportedVersionsExtension)
        self.assertEqual([(3, 3), (3, 4)], ext.versions)

    def test_parse_with_trailing_data(self):
        ext = TLSExtension()

        p = Parser(bytearray(
            b'\x00\x2b'  # type of ext
            b'\x00\x06'  # length
            b'\x04'      # length of array inside
            b'\x03\x03'  # first item
            b'\x03\x04'  # second item
            b'\x00'))    # trailing byte

        with self.assertRaises(SyntaxError):
            ext.parse(p)


class TestSrvSupportedVersionsExtension(unittest.TestCase):
    def test___init__(self):
        ext = SrvSupportedVersionsExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.version)
        self.assertEqual(bytearray(), ext.extData)
        self.assertEqual(43, ext.extType)

    def test_create(self):
        ext = SrvSupportedVersionsExtension()
        ext = ext.create((3, 4))

        self.assertEqual(ext.version, (3, 4))

        self.assertEqual("SrvSupportedVersionsExtension(version=(3, 4))",
                         str(ext))

    def test_extData(self):
        ext = SrvSupportedVersionsExtension().create((3, 4))

        self.assertEqual(bytearray(b'\x03\x04'), ext.extData)

    def test_parse_in_HRR(self):
        ext = TLSExtension(hrr=True)

        parser = Parser(bytearray(
            b'\x00\x2b'  # type of extension
            b'\x00\x02'  # length of extension
            b'\x03\x05'  # version
            ))

        ext = ext.parse(parser)

        self.assertIsInstance(ext, SrvSupportedVersionsExtension)
        self.assertEqual((3, 5), ext.version)

    def test_parse_in_SH(self):
        ext = TLSExtension(server=True)

        parser = Parser(bytearray(
            b'\x00\x2b'  # type of extension
            b'\x00\x02'  # length of extension
            b'\x03\x05'  # version
            ))

        ext = ext.parse(parser)

        self.assertIsInstance(ext, SrvSupportedVersionsExtension)
        self.assertEqual((3, 5), ext.version)

    def test_parse_malformed(self):
        ext = TLSExtension(server=True)

        parser = Parser(bytearray(
            b'\x00\x2b'  # type
            b'\x00\x03'  # length
            b'\x03\x05\x01'))  # payload

        with self.assertRaises(SyntaxError):
            ext.parse(parser)


class TestKeyShareEntry(unittest.TestCase):
    def setUp(self):
        self.kse = KeyShareEntry()

    def test___init__(self):
        self.assertIsNotNone(self.kse)

    def test_parse(self):
        p = Parser(bytearray(b'\x00\x12'  # group ID
                             b'\x00\x02'  # share length
                             b'\x01\x01'))  # key share

        self.kse = self.kse.parse(p)

        self.assertEqual(self.kse.group, 18)
        self.assertEqual(self.kse.key_exchange, bytearray(b'\x01\x01'))

    def test_write(self):
        w = Writer()

        self.kse.group = 18
        self.kse.key_exchange = bytearray(b'\x01\x01')

        self.kse.write(w)

        self.assertEqual(w.bytes, bytearray(b'\x00\x12'  # group ID
                                            b'\x00\x02'  # share length
                                            b'\x01\x01'))  # key share


class TestKeyShareExtension(unittest.TestCase):
    def setUp(self):
        self.cks = ClientKeyShareExtension()

    def test___init__(self):
        self.assertIsNotNone(self.cks)

    def test_create(self):
        entry = mock.Mock()
        self.cks = self.cks.create([entry])

        self.assertIs(self.cks.client_shares[0], entry)

    def test_extData(self):
        entries = [KeyShareEntry().create(10, bytearray(b'\x12\x13\x14')),
                   KeyShareEntry().create(12, bytearray(b'\x02'))]
        self.cks = self.cks.create(entries)

        self.assertEqual(self.cks.extData, bytearray(
            b'\x00\x0c'  # list length
            b'\x00\x0a'  # ID of first entry
            b'\x00\x03'  # length of share of first entry
            b'\x12\x13\x14'  # value of share of first entry
            b'\x00\x0c'  # ID of second entry
            b'\x00\x01'  # length of share of second entry
            b'\x02'))  # Value of share of second entry

    def test_parse(self):
        p = Parser(bytearray(
            b'\x00\x0c'  # list length
            b'\x00\x0a'  # ID of first entry
            b'\x00\x03'  # length of share of first entry
            b'\x12\x13\x14'  # value of share of first entry
            b'\x00\x0c'  # ID of second entry
            b'\x00\x01'  # length of share of second entry
            b'\x02'))  # Value of share of second entry

        self.cks = self.cks.parse(p)

        self.assertEqual(len(self.cks.client_shares), 2)
        self.assertIsInstance(self.cks.client_shares[0], KeyShareEntry)
        self.assertEqual(self.cks.client_shares[0].group, 10)
        self.assertEqual(self.cks.client_shares[0].key_exchange,
                         bytearray(b'\x12\x13\x14'))
        self.assertIsInstance(self.cks.client_shares[1], KeyShareEntry)
        self.assertEqual(self.cks.client_shares[1].group, 12)
        self.assertEqual(self.cks.client_shares[1].key_exchange,
                         bytearray(b'\x02'))

    def test_parse_missing_list(self):
        p = Parser(bytearray())

        self.cks = self.cks.parse(p)

        self.assertIsNone(self.cks.client_shares)

    def test_parse_empty_list(self):
        p = Parser(bytearray(b'\x00\x00'))

        self.cks = self.cks.parse(p)

        self.assertEqual([], self.cks.client_shares)

    def test_parse_with_trailing_data(self):
        p = Parser(bytearray(b'\x00\x00\x01'))

        with self.assertRaises(SyntaxError):
            self.cks.parse(p)


class TestServerKeyShareExtension(unittest.TestCase):
    def setUp(self):
        self.ext = ServerKeyShareExtension()

    def test__init__(self):
        self.assertIsNotNone(self.ext)
        self.assertIsInstance(self.ext, ServerKeyShareExtension)
        self.assertIsNone(self.ext.server_share)

    def test_create(self):
        ext = self.ext.create(bytearray(b'test'))

        self.assertIsInstance(ext, ServerKeyShareExtension)
        self.assertEqual(ext.server_share, bytearray(b'test'))

    def test_parse(self):
        parser = Parser(bytearray(
            b'\x00\x33'  # ID of key_share extension
            b'\x00\x07'  # length of the extension
            b'\x00\x0a'  # group ID of first entry
            b'\x00\x03'  # length of share of first entry
            b'\x12\x13\x14'  # value of share of first entry
            ))

        ext = TLSExtension(server=True)
        ext = ext.parse(parser)

        self.assertIsInstance(ext, ServerKeyShareExtension)
        self.assertIsInstance(ext.server_share, KeyShareEntry)
        self.assertEqual(ext.server_share.group, 10)
        self.assertEqual(ext.server_share.key_exchange,
                         bytearray(b'\x12\x13\x14'))

    def test_parse_with_no_data(self):
        parser = Parser(bytearray(
            b'\x00\x33'  # ID of key_share
            b'\x00\x00'  # empty payload
            ))
        ext = TLSExtension(server=True)
        ext = ext.parse(parser)

        self.assertIsInstance(ext, ServerKeyShareExtension)
        self.assertIsNone(ext.server_share)

    def test_parse_with_trailing_data(self):
        parser = Parser(bytearray(
            b'\x00\x33'  # ID of key_share extension
            b'\x00\x08'  # length of the extension
            b'\x00\x0a'  # group ID of first entry
            b'\x00\x03'  # length of share of first entry
            b'\x12\x13\x14'  # value of share of first entry
            b'\x00'  # trailing data
            ))

        ext = TLSExtension(server=True)
        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test_extData(self):
        entry = KeyShareEntry().create(10, bytearray(b'\x12\x13\x14'))
        self.ext.create(entry)

        self.assertEqual(self.ext.extData,
                bytearray(b'\x00\x0a'
                          b'\x00\x03'
                          b'\x12\x13\x14'))

    def test_extData_with_no_entry(self):
        self.assertEqual(self.ext.extData,
                         bytearray(0))


class TestCertificateStatusExtension(unittest.TestCase):
    def test___init__(self):
        cs = CertificateStatusExtension()

        self.assertIsNone(cs.status_type)
        self.assertIsNone(cs.response)

    def test_create(self):
        cs = CertificateStatusExtension()
        cs = cs.create(CertificateStatusType.ocsp, bytearray(b'resp'))

        self.assertIsInstance(cs, CertificateStatusExtension)
        self.assertEqual(cs.status_type, CertificateStatusType.ocsp)
        self.assertEqual(cs.response, bytearray(b'resp'))

    def test_extData(self):
        cs = CertificateStatusExtension()
        cs = cs.create(CertificateStatusType.ocsp, bytearray(b'resp'))

        self.assertEqual(cs.extData,
                bytearray(b'\x01'  # status type
                          b'\x00\x00\x04'  # length of response
                          b'resp'  # payload
                          ))

    def test_parse(self):
        cs = CertificateStatusExtension()

        parser = Parser(bytearray(b'\x01'  # type of ocsp response
                                  b'\x00\x00\x04'  # length
                                  b'resp'))  # payload

        cs = cs.parse(parser)

        self.assertIsInstance(cs, CertificateStatusExtension)
        self.assertEqual(cs.status_type, CertificateStatusType.ocsp)
        self.assertEqual(cs.response, bytearray(b'resp'))

    def test_parse_with_unknown_type(self):
        cs = CertificateStatusExtension()

        parser = Parser(bytearray(b'\x02'  # type of response
                                  b'\x00\x00\x04'  # length
                                  b'resp'))

        with self.assertRaises(SyntaxError):
            cs.parse(parser)

    def test_parse_with_trailing_data(self):
        cs = CertificateStatusExtension()
        parser = Parser(bytearray(b'\x01'  # type of ocsp response
                                  b'\x00\x00\x04'  # length
                                  b'resp'  # payload
                                  b'\x01'  # trailing data
                                  ))

        with self.assertRaises(SyntaxError):
            cs.parse(parser)


class TestHRRKeyShareExtension(unittest.TestCase):
    def test___init__(self):
        ext = HRRKeyShareExtension()

        self.assertIsNone(ext.selected_group)

    def test_create(self):
        val = mock.Mock()

        ext = HRRKeyShareExtension().create(val)

        self.assertIs(ext.selected_group, val)

    def test_extData(self):
        ext = HRRKeyShareExtension().create(GroupName.x25519)

        self.assertEqual(bytearray(b'\x00\x33'
                                   b'\x00\x02'
                                   b'\x00\x1d'),
                         ext.write())

    def test_extData_with_no_value(self):
        ext = HRRKeyShareExtension()

        self.assertEqual(ext.extData, bytearray())

    def test_parse(self):
        parser = Parser(bytearray(b'\x00\x33'
                                  b'\x00\x02'
                                  b'\x00\x1d'))
        ext = TLSExtension(hrr=True)
        ext = ext.parse(parser)

        self.assertIsInstance(ext, HRRKeyShareExtension)
        self.assertEqual(ext.selected_group, GroupName.x25519)

    def test_parse_with_trailing_data(self):
        parser = Parser(bytearray(b'\x00\x33'
                                  b'\x00\x03'
                                  b'\x00\x1d\x00'))
        ext = TLSExtension(hrr=True)
        with self.assertRaises(SyntaxError):
            ext.parse(parser)


class TestPreSharedKeyExtension(unittest.TestCase):
    def test___init__(self):
        ext = PreSharedKeyExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.identities)
        self.assertIsNone(ext.binders)

        self.assertEqual(ext.extType, 41)
        self.assertEqual(ext.extData, bytearray())

    def test_create(self):
        iden = mock.Mock()
        binder = mock.Mock()
        ext = PreSharedKeyExtension().create(iden, binder)

        self.assertIsInstance(ext, PreSharedKeyExtension)
        self.assertIs(ext.identities, iden)
        self.assertIs(ext.binders, binder)

    def test_write(self):
        iden = PskIdentity().create(bytearray(b'text'), 0)
        binder = bytearray([1] * 32)

        ext = PreSharedKeyExtension().create([iden], [binder])

        self.assertEqual(bytearray(
            b'\x00\x29' +  # ext type
            b'\x00\x2f' +  # ext length
            b'\x00\x0a' +  # identities length
            b'\x00\x04' +  # identity name length
            b'text' +  # identity name
            b'\x00\x00\x00\x00' +  # obfuscated_ticket_age
            b'\x00\x21' +  # binders length
            b'\x20' +  # binder length
            b'\x01' * 32  # binder
            ), ext.write())

    def test_parse(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x29' +  # ext type
            b'\x00\x2f' +  # ext length
            b'\x00\x0a' +  # identities length
            b'\x00\x04' +  # identity name length
            b'text' +  # identity name
            b'\x00\x00\x00\x00' +  # obfuscated_ticket_age
            b'\x00\x21' +  # binders length
            b'\x20' +  # binder length
            b'\x01' * 32))  # binder

        ext = ext.parse(parser)

        self.assertIsInstance(ext, PreSharedKeyExtension)

        self.assertEqual(ext.identities[0].identity, bytearray(b'text'))
        self.assertEqual(ext.identities[0].obfuscated_ticket_age, 0)
        self.assertEqual(len(ext.identities), 1)
        self.assertEqual(ext.binders[0], bytearray([1] * 32))
        self.assertEqual(len(ext.binders), 1)

    def test_parse_empty(self):
        ext = PreSharedKeyExtension().create(mock.Mock(), mock.Mock())
        parser = Parser(bytearray())

        ext = ext.parse(parser)

        self.assertIsNone(ext.identities)
        self.assertIsNone(ext.binders)

    def test_parse_with_extra_data(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x29' +  # ext type
            b'\x00\x30' +  # ext length
            b'\x00\x0a' +  # identities length
            b'\x00\x04' +  # identity name length
            b'text' +  # identity name
            b'\x00\x00\x00\x00' +  # obfuscated_ticket_age
            b'\x00\x21' +  # binders length
            b'\x20' +  # binder length
            b'\x01' * 32 +  # binder
            b'\x00')) # extra byte

        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test_parse_with_missing_data(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x29' +  # ext type
            b'\x00\x2e' +  # ext length
            b'\x00\x0a' +  # identities length
            b'\x00\x04' +  # identity name length
            b'text' +  # identity name
            b'\x00\x00\x00\x00' +  # obfuscated_ticket_age
            b'\x00\x21' +  # binders length
            b'\x20' +  # binder length
            b'\x01' * 31))  # binder

        with self.assertRaises(SyntaxError):
            ext.parse(parser)


class TestSrvPreSharedKeyExtension(unittest.TestCase):
    def test___init__(self):
        ext = SrvPreSharedKeyExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.selected)
        self.assertEqual(ext.extType, 41)
        self.assertEqual(ext.extData, bytearray())

    def test_create(self):
        ext = SrvPreSharedKeyExtension()

        sel = mock.Mock()
        ext = ext.create(sel)

        self.assertIsNotNone(ext)
        self.assertIs(ext.selected, sel)

    def test_write(self):
        ext = SrvPreSharedKeyExtension().create(12)

        self.assertEqual(bytearray(
            b'\x00\x29' +  # ext type
            b'\x00\x02' +  # ext length
            b'\x00\x0c'),  # selected identity
            ext.write())

    def test_parse_empty(self):
        ext = TLSExtension(server=True)

        parser = Parser(bytearray(
            b'\x00\x29'
            b'\x00\x00'))

        ext = ext.parse(parser)

        self.assertIsInstance(ext, SrvPreSharedKeyExtension)
        self.assertIsNone(ext.selected)

    def test_parse(self):
        ext = TLSExtension(server=True)

        parser = Parser(bytearray(
            b'\x00\x29'
            b'\x00\x02'
            b'\x00\x0a'))

        ext = ext.parse(parser)

        self.assertIsInstance(ext, SrvPreSharedKeyExtension)
        self.assertEqual(ext.selected, 10)

    def test_parse_with_extra_data(self):
        ext = TLSExtension(server=True)

        parser = Parser(bytearray(
            b'\x00\x29'
            b'\x00\x03'
            b'\x00\x0a'
            b'\x00'))


class TestHeartbeatExtension(unittest.TestCase):
    def test___init___(self):
        ext = HeartbeatExtension()

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extType, ExtensionType.heartbeat)
        self.assertIsNone(ext.mode)

    def test_create(self):
        ext = HeartbeatExtension().create(HeartbeatMode.PEER_ALLOWED_TO_SEND)

        self.assertIsNotNone(ext)
        self.assertEqual(ext.extType, ExtensionType.heartbeat)
        self.assertEqual(ext.mode, HeartbeatMode.PEER_ALLOWED_TO_SEND)

    def test_extData_none_mode(self):
        ext = HeartbeatExtension()

        self.assertEqual(ext.extData, bytearray(0))

    def test_extData_mode(self):
        ext = HeartbeatExtension().create(HeartbeatMode.PEER_ALLOWED_TO_SEND)

        self.assertEqual(ext.extData, b'\x01')

    def test_parse_with_no_data(self):
        parser = Parser(bytearray(0))

        ext = HeartbeatExtension()

        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test_parse(self):
        parser = Parser(bytearray(b'\x01'))

        ext = HeartbeatExtension().parse(parser)

        self.assertEqual(ext.mode, HeartbeatMode.PEER_ALLOWED_TO_SEND)

    def test_parse_with_too_much_data(self):
        parser = Parser(bytearray(b'\x01\x00'))

        ext = HeartbeatExtension()

        with self.assertRaises(SyntaxError):
            ext.parse(parser)


class TestPskKeyExchangeModesExtension(unittest.TestCase):
    def test___init__(self):
        ext = PskKeyExchangeModesExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.modes)
        self.assertEqual(ext.extType, 45)
        self.assertEqual(ext.extData, bytearray())

    def test_create(self):
        ext = PskKeyExchangeModesExtension()
        ext = ext.create([0])

        self.assertIsInstance(ext, PskKeyExchangeModesExtension)
        self.assertEqual(ext.modes, [0])

    def test_write(self):
        ext = PskKeyExchangeModesExtension().create([0])

        self.assertEqual(bytearray(
            b'\x00\x2d' +  # type
            b'\x00\x02' +  # ext length
            b'\x01' +  # array length
            b'\x00'),  # first item - psk_ke
            ext.write())

    def test_parse(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x2d' +  # type
            b'\x00\x02' +  # ext length
            b'\x01' +  # array length
            b'\x00'))  # first item - psk_ke

        ext = ext.parse(parser)

        self.assertIsInstance(ext, PskKeyExchangeModesExtension)
        self.assertEqual(ext.modes, [0])

    def test_parse_empty(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x2d' +  # type
            b'\x00\x00'))  # length

        ext = ext.parse(parser)

        self.assertIsInstance(ext, PskKeyExchangeModesExtension)
        self.assertIsNone(ext.modes)

    def test_parse_with_extra_data(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x2d' +  # type
            b'\x00\x03' +  # overall length
            b'\x01' +  # array length
            b'\x00' +  # array item
            b'\x00'))  # extra bytes

        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test___repr__(self):
        ext = PskKeyExchangeModesExtension().create([0, 1, 40])

        self.assertEqual(
            repr(ext),
            "PskKeyExchangeModesExtension(modes=[psk_ke, psk_dhe_ke, 40])")


class TestCookieExtension(unittest.TestCase):
    def test___init__(self):
        ext = CookieExtension()

        self.assertIsNotNone(ext)
        self.assertIsNone(ext.cookie)
        self.assertEqual(ext.extType, 44)
        self.assertEqual(ext.extData, bytearray())

    def test_create(self):
        ext = CookieExtension()
        ext = ext.create(bytearray(b'test payload'))

        self.assertIsInstance(ext, CookieExtension)
        self.assertEqual(ext.cookie, bytearray(b'test payload'))

    def test_write(self):
        ext = CookieExtension().create(b"test")

        self.assertEqual(bytearray(
            b'\x00\x2c' +  # type
            b'\x00\x06' +  # overall length
            b'\x00\x04' +  # cookie length
            b'test'), ext.write())

    def test_parse(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x2c' +  # type
            b'\x00\x06' +  # overall length
            b'\x00\x04' +  # cookie length
            b'test'))

        ext = ext.parse(parser)

        self.assertIsInstance(ext, CookieExtension)
        self.assertEqual(ext.cookie, bytearray(b'test'))

    def test_parse_empty(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x2c' +  # type
            b'\x00\x00'))  # ext length

        ext = ext.parse(parser)

        self.assertIsInstance(ext, CookieExtension)
        self.assertIsNone(ext.cookie)

    def test_parse_with_extra_data(self):
        ext = TLSExtension()

        parser = Parser(bytearray(
            b'\x00\x2c' +  # type
            b'\x00\x08' +  # overall length
            b'\x00\x04' +  # cookie length
            b'test' +  # cookie
            b'XX'))  # extra data

        with self.assertRaises(SyntaxError):
            ext.parse(parser)

    def test___repr__(self):
        ext = CookieExtension().create(b'test')

        self.assertEqual(
            repr(ext),
            "CookieExtension(len(cookie)=4)")

    def test___repr___with_none(self):
        ext = CookieExtension()
        self.assertEqual(repr(ext), "CookieExtension(cookie=None)")


if __name__ == '__main__':
    unittest.main()
