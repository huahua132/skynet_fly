
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

from tlslite.utils.python_key import Python_Key
from tlslite.utils.python_rsakey import Python_RSAKey
from tlslite.utils.python_ecdsakey import Python_ECDSAKey
from tlslite.utils.python_dsakey import Python_DSAKey

class TestKey(unittest.TestCase):
    def test_rsa_key(self):
        key = (
            "-----BEGIN PRIVATE KEY-----\n"
            "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDmM/tmq/2/N0Yy\n"
            "qBb2Bu2X3+zdAU+6lnUsz+pNN69nM20aNPi9QH4ekyxs/x+uj37Zlw2hDwA5pifA\n"
            "44kFtOXkw1ex4lS1xxtWCuGu1YXTDgxS1I1dcNa4qdYvwlgBGyx2T0GdIDeG3sWN\n"
            "WOx2OXBeW6wm0RRxqUhyI9SXaN8yQWsCaajPZxw89OJ1XaSShWrfD2xq6xmQYV6Y\n"
            "P6KcIORlQG21a6BvDbewE3iM2OGAmlEv/a7OydKlerWrc3oFBBoOmgnbLuBaxkBQ\n"
            "Nv0UQrRBfB+QOoD3cE3seAjkfkVV22llJ5cMn00YwFRdsRYlgNFkoS3k25YsTMb+\n"
            "NqlGYnR1AgMBAAECggEAUCu6Wj9716RAZlPz6yrug/4QV8elJK5RkJG4X7wM8jwO\n"
            "uxnHpuFXCv7mce9H8Vs4Kj9ZF8ZJpcof/iVACyS9C7acS+8u4T++XXDcuC7UtHQo\n"
            "BpDPysMJhLZhSbC9RWVZTrq7dyVJMUdUNa3KbEIEyFfU1I/sNsll2Zpw52o2kSFe\n"
            "Ip1TGcnVmFu0uKxPrlNLSSNOVQqz2fOYWBJLk98gk54HAkHpFk92FVorn17seAfS\n"
            "ksF70B9X6MBUa6PDSgQfKCwGd27KBpTivx6d8QVtMNqrFq/cqZ7TwWDIq1atZ0aF\n"
            "3mYXfXR0toRyYZEXaa14Ao7iCUt5D8d2IG9u3q88AQKBgQD5x6kiqO+ApY7V0S0g\n"
            "SyaIdTBjYc9Rbb0qvgy0Mhq68Ekc2fBIdTLc+G9ajkVFIe5blZc0nvwgSLdRfWrJ\n"
            "bFpX8SS9Aelgp0mcfXgfIpJmLrPijtgEipTCh/73GTJM3ZnHI1z6xrRP0hi1ww2Q\n"
            "Z8oqF34H6glXfYHfMqy9VaGQ4QKBgQDr74T4BxiXK4dIQ0T4oRE/881dScrVz9Ok\n"
            "3wPINa5bIvfqHPl3eAJgRYBkxjKRyxt29wvGtWBQvCTHvFgF9F+3v3mfXJPRHaZZ\n"
            "e1VJn9Eqjz1KuArIOwSrmnCFrd9jim10Qo36AFU0myridllN/NQn4l7yYgnw2a1/\n"
            "WbLYq2nSFQKBgAkJWyog2IFb+/3qUmqfrWY0byq5SCnXAYgBVi5SvbrTpKGBlPra\n"
            "Gpv59PVevkzQ/HGdyNmjgtWcK92r3ugonmAeHkkkP5A6nSQnOehOdONzfxiMOG55\n"
            "oQYkq2m/JJ25Sq30rpF4DN/yZuh0hRIbXyoErY+VvP7IUKGFkNBMv8qhAoGBANDV\n"
            "pLPJzClanRcIfA86ukMKMPfm7kQM/gAMapOXeGow7JHr7aCiuC+wtTH+ARrtVbUa\n"
            "fPD48HTl5ARroNo8cVD6idPWJPzPKsQ/l8FgVcs/GHh/qQOMwdiHDhw1R+sax0FF\n"
            "+9eS3dh/lBj5uph+NufKxlHzF2t5sclsgxKnvzX1AoGAZlNZt2xn3q/kusUXLovS\n"
            "WN8C3ty06qLbD99kiWqEC2gSXc94rk7K7R/1XgfxXV8uOA9eUPDBpchd9PUnhwBE\n"
            "tnkuQZ0fZ1P6EpNTumeL/UvIaA2UFtqrzxxJPJQExPRqX5foT6FhXVtGrNGKw78C\n"
            "Ft7IqSkjX742rx0ephmvZgE=\n"
            "-----END PRIVATE KEY-----")

        parsed_key = Python_Key.parsePEM(key)

        self.assertIsInstance(parsed_key, Python_RSAKey)

        exp_n = int("29060443439214279856616714317441381282994349643640084870"
                    "42194472422505198384747878467307665661184232728624861572"
                    "46118030874616185167217887082030330066913757629456433183"
                    "57727014263595982166729996386221650476766003639153689499"
                    "85761113451052281630236293941677142748838601564606627814"
                    "78871504321887555454323655057925411605057705083616507918"
                    "02130319371355483088627276339169052633563469569700890323"
                    "45345689545843561543977465544801728579255200638380126710"
                    "78271693450544506178122783381759966742683127796190767251"
                    "31801425088592558384516012482302720815493207137857605058"
                    "06980478584101642143302393556465736571436454903701271051"
                    "7")

        self.assertEqual(parsed_key.n, exp_n)

    def test_ecdsa_key_pkcs8(self):
        key = (
            "-----BEGIN PRIVATE KEY-----\n"
            "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgCOZr0Ovs0eCmh+XM\n"
            "QWDYVpsQ+sJdjiq/itp/kYnWNSahRANCAATINGMQAl7cXlPrYzJluGOgmc8sYvae\n"
            "tO2EsXKYG6lnYhudZiepVYORP8vqLyxCF/bMIuuVKOPWSfsRGo/H8pnK\n"
            "-----END PRIVATE KEY-----\n")

        parsed_key = Python_Key.parsePEM(key)

        self.assertIsInstance(parsed_key, Python_ECDSAKey)
        self.assertEqual(parsed_key.private_key.privkey.secret_multiplier,
                         int("40256217329389834316473379676481509423"
                             "54978248437138490984956489316429083942"))
        self.assertIsNotNone(parsed_key.public_key)

    def test_ecdsa_key_ssleay(self):
        key = (
            "-----BEGIN EC PRIVATE KEY-----\n"
            "MHcCAQEEIAjma9Dr7NHgpoflzEFg2FabEPrCXY4qv4raf5GJ1jUmoAoGCCqGSM49\n"
            "AwEHoUQDQgAEyDRjEAJe3F5T62MyZbhjoJnPLGL2nrTthLFymBupZ2IbnWYnqVWD\n"
            "kT/L6i8sQhf2zCLrlSjj1kn7ERqPx/KZyg==\n"
            "-----END EC PRIVATE KEY-----\n")

        parsed_key = Python_Key.parsePEM(key)

        self.assertIsInstance(parsed_key, Python_ECDSAKey)
        self.assertEqual(parsed_key.private_key.privkey.secret_multiplier,
                         int("40256217329389834316473379676481509423"
                             "54978248437138490984956489316429083942"))
        self.assertIsNotNone(parsed_key.public_key)

    def test_ecdsa_p224(self):
        key = (
            "-----BEGIN PRIVATE KEY-----\n"
            "MHgCAQAwEAYHKoZIzj0CAQYFK4EEACEEYTBfAgEBBBxFHtoSt2Sbng5P70Pq04xU\n"
            "dYOeuyeaf03bQojMoTwDOgAED9EfhLHR46fj4wD1SDbSU7wwgnjzXdCTcidCsuC5\n"
            "fvLd2Tvc4Pdjmhxc0btlNvWMM5HmoRqj4vk=\n"
            "-----END PRIVATE KEY-----\n")

        # secp224r1 is not supported by tlslite-ng
        with self.assertRaises(SyntaxError) as e:
            Python_Key.parsePEM(key)

        self.assertIn("Unknown curve", str(e.exception))

    def test_ecdsa_p384(self):
        key = (
            "-----BEGIN PRIVATE KEY-----\n"
            "MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDDjdQHtIxZwXVK9qPzt\n"
            "pE6QSrzpSxmW2HvQm6D2l6+w48insmcdZkIoDSTCclVlZpihZANiAATz74XG7gPG\n"
            "DOe2ipv1WN3QYQ8dCsJ5evMTX2VmMxF3wByPqrdr9g4dpQo2U9Rm2xxTwi6xZvFK\n"
            "08lqBXsIjrUYnEahj25AKDMsyiZgiUJPlTFlg9/qprk5+4o9WMQBalQ=\n"
            "-----END PRIVATE KEY-----\n")

        parsed_key = Python_Key.parsePEM(key)

        self.assertIsInstance(parsed_key, Python_ECDSAKey)
        self.assertEqual(len(parsed_key), 384)

    def test_ecdsa_p521(self):
        key = (
            "-----BEGIN PRIVATE KEY-----\n"
            "MIHuAgEAMBAGByqGSM49AgEGBSuBBAAjBIHWMIHTAgEBBEIBS376Hksl8eIvBbU1\n"
            "TgpGdlZK32zjgjFDp5IdaTaK5nkH2g35n2Iv5pWMcCvVA4cHKIi6nsJzNFQIPRZ/\n"
            "8smb9EmhgYkDgYYABAHrw9Ud/fJGfzIp+EqNU/JlohUG+uidSJQ2E6o2y6qnHslE\n"
            "U6FqdQItZQze162e6xaDZOrHOMeYGGiO+KdJmCF7pACSOS13NdebB7GH6kgAuM2t\n"
            "rN12KXJk4qvC65CxpUudQW04fK0zcRi3zRNAuWgSClTQC1WMF2QgjlVgQr3ZD1A5\n"
            "sw==\n"
            "-----END PRIVATE KEY-----\n")

        parsed_key = Python_Key.parsePEM(key)

        self.assertIsInstance(parsed_key, Python_ECDSAKey)
        self.assertEqual(len(parsed_key), 521)

    def test_dsa_key_pkcs8(self):
        key_PKCS8 = (
                "-----BEGIN PRIVATE KEY-----\n"
                "MIGEAgEAMGcGByqGSM44BAEwXAIhAJnhWwlIVVGYFaZY1zm4ZkWkGCENdmEq/c5Q\n"
                "o2tpKU4lAhUAnwsmoLxA5ICuZx6rHGmJRd9npEcCIGIKTT/CY1cXyeD9yBKztO6q\n"
                "s1kttYUsjIbGgjdGp9DrBBYCFAmQlcW6FkMRHVfA7C82IVhQ89lo\n"
                "-----END PRIVATE KEY-----\n")
        parsed_key = Python_Key.parsePEM(key_PKCS8)
        self.assertIsInstance(parsed_key, Python_DSAKey)
        self.assertTrue(parsed_key.hasPrivateKey())
        self.assertEqual(parsed_key.private_key,    \
                54605271259585079176392566431938393409383029096)
