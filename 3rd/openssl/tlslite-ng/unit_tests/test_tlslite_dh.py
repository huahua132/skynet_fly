
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

from tlslite.dh import parse, parseBinary


class TestParse(unittest.TestCase):
    def test_pem(self):
        data = (
            "-----BEGIN DH PARAMETERS-----\n"
            "MIGHAoGBAIj4luOWCbrxyrPJOAhn4tG6jO8F1AaiiBBm1eAEEdQTKuhdV1uBBQDL\n"
            "ve3O/ZrR9x+ILs9PIUgZMSFP8X5ldBAFjEIoTmfneSB4TcKN27gpiRFZK0eFTi9F\n"
            "mofd/BgLWrNAHAOhBG7V6Gz7lZaFOxhxGTH+Lx6HxiTM7+RsLMSLAgEC\n"
            "-----END DH PARAMETERS-----\n")

        g, p = parse(data)

        self.assertEqual(p, int("88F896E39609BAF1CAB3C9380867E2D1BA8CEF05D406"
            "A2881066D5E00411D4132AE85D575B810500CBBDEDCEFD9AD1F71F882ECF4F21"
            "481931214FF17E657410058C42284E67E77920784DC28DDBB8298911592B4785"
            "4E2F459A87DDFC180B5AB3401C03A1046ED5E86CFB9596853B18711931FE2F1E"
            "87C624CCEFE46C2CC48B", 16))
        self.assertEqual(g, 2)

    def test_der(self):
        data = bytearray(
            b"\x30\x81\x87\x02\x81\x81\x00\x88\xf8\x96\xe3\x96\x09\xba\xf1\xca"
            b"\xb3\xc9\x38\x08\x67\xe2\xd1\xba\x8c\xef\x05\xd4\x06\xa2\x88\x10"
            b"\x66\xd5\xe0\x04\x11\xd4\x13\x2a\xe8\x5d\x57\x5b\x81\x05\x00\xcb"
            b"\xbd\xed\xce\xfd\x9a\xd1\xf7\x1f\x88\x2e\xcf\x4f\x21\x48\x19\x31"
            b"\x21\x4f\xf1\x7e\x65\x74\x10\x05\x8c\x42\x28\x4e\x67\xe7\x79\x20"
            b"\x78\x4d\xc2\x8d\xdb\xb8\x29\x89\x11\x59\x2b\x47\x85\x4e\x2f\x45"
            b"\x9a\x87\xdd\xfc\x18\x0b\x5a\xb3\x40\x1c\x03\xa1\x04\x6e\xd5\xe8"
            b"\x6c\xfb\x95\x96\x85\x3b\x18\x71\x19\x31\xfe\x2f\x1e\x87\xc6\x24"
            b"\xcc\xef\xe4\x6c\x2c\xc4\x8b\x02\x01\x02")

        g, p = parse(data)

        self.assertEqual(p, int("88F896E39609BAF1CAB3C9380867E2D1BA8CEF05D406"
            "A2881066D5E00411D4132AE85D575B810500CBBDEDCEFD9AD1F71F882ECF4F21"
            "481931214FF17E657410058C42284E67E77920784DC28DDBB8298911592B4785"
            "4E2F459A87DDFC180B5AB3401C03A1046ED5E86CFB9596853B18711931FE2F1E"
            "87C624CCEFE46C2CC48B", 16))
        self.assertEqual(g, 2)
