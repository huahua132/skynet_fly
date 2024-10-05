# GOST provider

The GOST provider is currently built in parallell with the GOST
engine, and is implemented like a wrapper around the engine code.

## Currently implemented

Symmetric ciphers:

-   gost89
-   gost89-cnt
-   gost89-cnt-12
-   gost89-cbc
-   kuznyechik-ecb
-   kuznyechik-cbc
-   kuznyechik-cfb
-   kuznyechik-ofb
-   kuznyechik-ctr
-   magma-cbc
-   magma-ctr
-   magma-ctr-acpkm
-   magma-ctr-acpkm-omac
-   kuznyechik-ctr-acpkm
-   kuznyechik-ctr-acpkm-omac

Hashes:

-   id-tc26-gost3411-12-256 (md_gost12_256)
-   id-tc26-gost3411-12-512 (md_gost12_512)
-   id-GostR3411-94 (md_gost94)

MACs:

-   gost-mac
-   gost-mac-12
-   magma-mac
-   kuznyechik-mac
-   kuznyechik-ctr-acpkm-omac

## TODO, not requiring additional OpenSSL support

-   Basic support for GOST keys, i.e. implementations of KEYMGMT
    (including key generation), DECODER and DECODER.

-   Support for these operations using GOST keys:

    -   ASYM_CIPHER (encryption and decryption using GOST keys)
    -   SIGNATURE (signing and verifying using GOST keys)
    
## TODO, which requires additional OpenSSL support

-   TLSTREE support.  This may require additional changes in libssl.
    Needs investigation.

-   PKCS7 and CMS support.  This requires OpenSSL PKCS7 and CMS code
    to change for better interfacing with providers.

## TODO, far future

-   Refactor the code into being just a provider.  This is to be done
    when engines aren't supported any more.
