Algorithms supported
====================

This page lists all quantum-safe algorithms supported by oqs-provider.

Some algorithms by default may not be enabled for use in the master code-generator template file.

As standardization for these algorithms within TLS is not done, all TLS code points/IDs can be changed from their default values to values set by environment variables. This facilitates interoperability testing with TLS1.3 implementations that use different IDs.

# Code points / algorithm IDs

<!--- OQS_TEMPLATE_FRAGMENT_IDS_START -->
|Algorithm name | default ID | enabled | environment variable |
|---------------|:----------:|:-------:|----------------------|
| frodo640aes | 0x0200 | Yes | OQS_CODEPOINT_FRODO640AES |
| p256_frodo640aes | 0x2F00 | Yes | OQS_CODEPOINT_P256_FRODO640AES |
| x25519_frodo640aes | 0x2F80 | Yes | OQS_CODEPOINT_X25519_FRODO640AES |
| frodo640shake | 0x0201 | Yes | OQS_CODEPOINT_FRODO640SHAKE |
| p256_frodo640shake | 0x2F01 | Yes | OQS_CODEPOINT_P256_FRODO640SHAKE |
| x25519_frodo640shake | 0x2F81 | Yes | OQS_CODEPOINT_X25519_FRODO640SHAKE |
| frodo976aes | 0x0202 | Yes | OQS_CODEPOINT_FRODO976AES |
| p384_frodo976aes | 0x2F02 | Yes | OQS_CODEPOINT_P384_FRODO976AES |
| x448_frodo976aes | 0x2F82 | Yes | OQS_CODEPOINT_X448_FRODO976AES |
| frodo976shake | 0x0203 | Yes | OQS_CODEPOINT_FRODO976SHAKE |
| p384_frodo976shake | 0x2F03 | Yes | OQS_CODEPOINT_P384_FRODO976SHAKE |
| x448_frodo976shake | 0x2F83 | Yes | OQS_CODEPOINT_X448_FRODO976SHAKE |
| frodo1344aes | 0x0204 | Yes | OQS_CODEPOINT_FRODO1344AES |
| p521_frodo1344aes | 0x2F04 | Yes | OQS_CODEPOINT_P521_FRODO1344AES |
| frodo1344shake | 0x0205 | Yes | OQS_CODEPOINT_FRODO1344SHAKE |
| p521_frodo1344shake | 0x2F05 | Yes | OQS_CODEPOINT_P521_FRODO1344SHAKE |
| kyber512 | 0x023A | Yes | OQS_CODEPOINT_KYBER512 |
| p256_kyber512 | 0x2F3A | Yes | OQS_CODEPOINT_P256_KYBER512 |
| x25519_kyber512 | 0x2F39 | Yes | OQS_CODEPOINT_X25519_KYBER512 |
| kyber768 | 0x023C | Yes | OQS_CODEPOINT_KYBER768 |
| p384_kyber768 | 0x2F3C | Yes | OQS_CODEPOINT_P384_KYBER768 |
| x448_kyber768 | 0x2F90 | Yes | OQS_CODEPOINT_X448_KYBER768 |
| x25519_kyber768 | 0x6399 | Yes | OQS_CODEPOINT_X25519_KYBER768 |
| p256_kyber768 | 0x639A | Yes | OQS_CODEPOINT_P256_KYBER768 |
| kyber1024 | 0x023D | Yes | OQS_CODEPOINT_KYBER1024 |
| p521_kyber1024 | 0x2F3D | Yes | OQS_CODEPOINT_P521_KYBER1024 |
| mlkem512 | 0x0247 | Yes | OQS_CODEPOINT_MLKEM512 |
| p256_mlkem512 | 0x2F47 | Yes | OQS_CODEPOINT_P256_MLKEM512 |
| x25519_mlkem512 | 0x2FB2 | Yes | OQS_CODEPOINT_X25519_MLKEM512 |
| mlkem768 | 0x0248 | Yes | OQS_CODEPOINT_MLKEM768 |
| p384_mlkem768 | 0x2F48 | Yes | OQS_CODEPOINT_P384_MLKEM768 |
| x448_mlkem768 | 0x2FB3 | Yes | OQS_CODEPOINT_X448_MLKEM768 |
| x25519_mlkem768 | 0x2FB4 | Yes | OQS_CODEPOINT_X25519_MLKEM768 |
| p256_mlkem768 | 0x2FB5 | Yes | OQS_CODEPOINT_P256_MLKEM768 |
| mlkem1024 | 0x0249 | Yes | OQS_CODEPOINT_MLKEM1024 |
| p521_mlkem1024 | 0x2F49 | Yes | OQS_CODEPOINT_P521_MLKEM1024 |
| p384_mlkem1024 | 0x2F4A | Yes | OQS_CODEPOINT_P384_MLKEM1024 |
| bikel1 | 0x0241 | Yes | OQS_CODEPOINT_BIKEL1 |
| p256_bikel1 | 0x2F41 | Yes | OQS_CODEPOINT_P256_BIKEL1 |
| x25519_bikel1 | 0x2FAE | Yes | OQS_CODEPOINT_X25519_BIKEL1 |
| bikel3 | 0x0242 | Yes | OQS_CODEPOINT_BIKEL3 |
| p384_bikel3 | 0x2F42 | Yes | OQS_CODEPOINT_P384_BIKEL3 |
| x448_bikel3 | 0x2FAF | Yes | OQS_CODEPOINT_X448_BIKEL3 |
| bikel5 | 0x0243 | Yes | OQS_CODEPOINT_BIKEL5 |
| p521_bikel5 | 0x2F43 | Yes | OQS_CODEPOINT_P521_BIKEL5 |
| hqc128 | 0x0244 | Yes | OQS_CODEPOINT_HQC128 |
| p256_hqc128 | 0x2F44 | Yes | OQS_CODEPOINT_P256_HQC128 |
| x25519_hqc128 | 0x2FB0 | Yes | OQS_CODEPOINT_X25519_HQC128 |
| hqc192 | 0x0245 | Yes | OQS_CODEPOINT_HQC192 |
| p384_hqc192 | 0x2F45 | Yes | OQS_CODEPOINT_P384_HQC192 |
| x448_hqc192 | 0x2FB1 | Yes | OQS_CODEPOINT_X448_HQC192 |
| hqc256 | 0x0246 | Yes | OQS_CODEPOINT_HQC256 |
| p521_hqc256 | 0x2F46 | Yes | OQS_CODEPOINT_P521_HQC256 |
| dilithium2 | 0xfea0 |Yes| OQS_CODEPOINT_DILITHIUM2
| p256_dilithium2 | 0xfea1 |Yes| OQS_CODEPOINT_P256_DILITHIUM2
| rsa3072_dilithium2 | 0xfea2 |Yes| OQS_CODEPOINT_RSA3072_DILITHIUM2
| dilithium3 | 0xfea3 |Yes| OQS_CODEPOINT_DILITHIUM3
| p384_dilithium3 | 0xfea4 |Yes| OQS_CODEPOINT_P384_DILITHIUM3
| dilithium5 | 0xfea5 |Yes| OQS_CODEPOINT_DILITHIUM5
| p521_dilithium5 | 0xfea6 |Yes| OQS_CODEPOINT_P521_DILITHIUM5
| mldsa44 | 0xfed0 |Yes| OQS_CODEPOINT_MLDSA44
| p256_mldsa44 | 0xfed3 |Yes| OQS_CODEPOINT_P256_MLDSA44
| rsa3072_mldsa44 | 0xfed4 |Yes| OQS_CODEPOINT_RSA3072_MLDSA44
| mldsa65 | 0xfed1 |Yes| OQS_CODEPOINT_MLDSA65
| p384_mldsa65 | 0xfed5 |Yes| OQS_CODEPOINT_P384_MLDSA65
| mldsa87 | 0xfed2 |Yes| OQS_CODEPOINT_MLDSA87
| p521_mldsa87 | 0xfed6 |Yes| OQS_CODEPOINT_P521_MLDSA87
| falcon512 | 0xfed7 |Yes| OQS_CODEPOINT_FALCON512
| p256_falcon512 | 0xfed8 |Yes| OQS_CODEPOINT_P256_FALCON512
| rsa3072_falcon512 | 0xfed9 |Yes| OQS_CODEPOINT_RSA3072_FALCON512
| falconpadded512 | 0xfedc |Yes| OQS_CODEPOINT_FALCONPADDED512
| p256_falconpadded512 | 0xfedd |Yes| OQS_CODEPOINT_P256_FALCONPADDED512
| rsa3072_falconpadded512 | 0xfede |Yes| OQS_CODEPOINT_RSA3072_FALCONPADDED512
| falcon1024 | 0xfeda |Yes| OQS_CODEPOINT_FALCON1024
| p521_falcon1024 | 0xfedb |Yes| OQS_CODEPOINT_P521_FALCON1024
| falconpadded1024 | 0xfedf |Yes| OQS_CODEPOINT_FALCONPADDED1024
| p521_falconpadded1024 | 0xfee0 |Yes| OQS_CODEPOINT_P521_FALCONPADDED1024
| sphincssha2128fsimple | 0xfeb3 |Yes| OQS_CODEPOINT_SPHINCSSHA2128FSIMPLE
| p256_sphincssha2128fsimple | 0xfeb4 |Yes| OQS_CODEPOINT_P256_SPHINCSSHA2128FSIMPLE
| rsa3072_sphincssha2128fsimple | 0xfeb5 |Yes| OQS_CODEPOINT_RSA3072_SPHINCSSHA2128FSIMPLE
| sphincssha2128ssimple | 0xfeb6 |Yes| OQS_CODEPOINT_SPHINCSSHA2128SSIMPLE
| p256_sphincssha2128ssimple | 0xfeb7 |Yes| OQS_CODEPOINT_P256_SPHINCSSHA2128SSIMPLE
| rsa3072_sphincssha2128ssimple | 0xfeb8 |Yes| OQS_CODEPOINT_RSA3072_SPHINCSSHA2128SSIMPLE
| sphincssha2192fsimple | 0xfeb9 |Yes| OQS_CODEPOINT_SPHINCSSHA2192FSIMPLE
| p384_sphincssha2192fsimple | 0xfeba |Yes| OQS_CODEPOINT_P384_SPHINCSSHA2192FSIMPLE
| sphincssha2192ssimple | 0xfebb |No| OQS_CODEPOINT_SPHINCSSHA2192SSIMPLE
| p384_sphincssha2192ssimple | 0xfebc |No| OQS_CODEPOINT_P384_SPHINCSSHA2192SSIMPLE
| sphincssha2256fsimple | 0xfebd |No| OQS_CODEPOINT_SPHINCSSHA2256FSIMPLE
| p521_sphincssha2256fsimple | 0xfebe |No| OQS_CODEPOINT_P521_SPHINCSSHA2256FSIMPLE
| sphincssha2256ssimple | 0xfec0 |No| OQS_CODEPOINT_SPHINCSSHA2256SSIMPLE
| p521_sphincssha2256ssimple | 0xfec1 |No| OQS_CODEPOINT_P521_SPHINCSSHA2256SSIMPLE
| sphincsshake128fsimple | 0xfec2 |Yes| OQS_CODEPOINT_SPHINCSSHAKE128FSIMPLE
| p256_sphincsshake128fsimple | 0xfec3 |Yes| OQS_CODEPOINT_P256_SPHINCSSHAKE128FSIMPLE
| rsa3072_sphincsshake128fsimple | 0xfec4 |Yes| OQS_CODEPOINT_RSA3072_SPHINCSSHAKE128FSIMPLE
| sphincsshake128ssimple | 0xfec5 |No| OQS_CODEPOINT_SPHINCSSHAKE128SSIMPLE
| p256_sphincsshake128ssimple | 0xfec6 |No| OQS_CODEPOINT_P256_SPHINCSSHAKE128SSIMPLE
| rsa3072_sphincsshake128ssimple | 0xfec7 |No| OQS_CODEPOINT_RSA3072_SPHINCSSHAKE128SSIMPLE
| sphincsshake192fsimple | 0xfec8 |No| OQS_CODEPOINT_SPHINCSSHAKE192FSIMPLE
| p384_sphincsshake192fsimple | 0xfec9 |No| OQS_CODEPOINT_P384_SPHINCSSHAKE192FSIMPLE
| sphincsshake192ssimple | 0xfeca |No| OQS_CODEPOINT_SPHINCSSHAKE192SSIMPLE
| p384_sphincsshake192ssimple | 0xfecb |No| OQS_CODEPOINT_P384_SPHINCSSHAKE192SSIMPLE
| sphincsshake256fsimple | 0xfecc |No| OQS_CODEPOINT_SPHINCSSHAKE256FSIMPLE
| p521_sphincsshake256fsimple | 0xfecd |No| OQS_CODEPOINT_P521_SPHINCSSHAKE256FSIMPLE
| sphincsshake256ssimple | 0xfece |No| OQS_CODEPOINT_SPHINCSSHAKE256SSIMPLE
| p521_sphincsshake256ssimple | 0xfecf |No| OQS_CODEPOINT_P521_SPHINCSSHAKE256SSIMPLE
<!--- OQS_TEMPLATE_FRAGMENT_IDS_END -->

Changing code points
--------------------

In order to dynamically change the code point of any one algorithm, the respective
environment variable listed above has to be set to the `INT`eger value of the
desired code point. For example, as Cloudflare has chosen `0xfe30` as the code
point for their hybrid X25519_kyber512 implementation, the following command
can be used to successfully confirm interoperability between the oqs-provider
and the Cloudflare infrastructure using this hybrid classic/quantum-safe algorithm:

```
OQS_CODEPOINT_X25519_KYBER512=65072  ./openssl/apps/openssl s_client -groups x25519_kyber512 -connect cloudflare.com:443 -provider-path _build/oqsprov -provider oqsprovider -provider default
```

# OIDs

Along the same lines as the code points, X.509 OIDs may be subject to change
prior to final standardization. The environment variables below permit
adapting the OIDs of all supported signature algorithms as per the table below.

<!--- OQS_TEMPLATE_FRAGMENT_OIDS_START -->
|Algorithm name |    default OID    | enabled | environment variable |
|---------------|:-----------------:|:-------:|----------------------|
| dilithium2 | 1.3.6.1.4.1.2.267.7.4.4 |Yes| OQS_OID_DILITHIUM2
| p256_dilithium2 | 1.3.9999.2.7.1 |Yes| OQS_OID_P256_DILITHIUM2
| rsa3072_dilithium2 | 1.3.9999.2.7.2 |Yes| OQS_OID_RSA3072_DILITHIUM2
| dilithium3 | 1.3.6.1.4.1.2.267.7.6.5 |Yes| OQS_OID_DILITHIUM3
| p384_dilithium3 | 1.3.9999.2.7.3 |Yes| OQS_OID_P384_DILITHIUM3
| dilithium5 | 1.3.6.1.4.1.2.267.7.8.7 |Yes| OQS_OID_DILITHIUM5
| p521_dilithium5 | 1.3.9999.2.7.4 |Yes| OQS_OID_P521_DILITHIUM5
| mldsa44 | 1.3.6.1.4.1.2.267.12.4.4 |Yes| OQS_OID_MLDSA44
| p256_mldsa44 | 1.3.9999.7.1 |Yes| OQS_OID_P256_MLDSA44
| rsa3072_mldsa44 | 1.3.9999.7.2 |Yes| OQS_OID_RSA3072_MLDSA44
| mldsa44_pss2048 | 2.16.840.1.114027.80.8.1.1 |Yes| OQS_OID_MLDSA44_pss2048
| mldsa44_rsa2048 | 2.16.840.1.114027.80.8.1.2 |Yes| OQS_OID_MLDSA44_rsa2048
| mldsa44_ed25519 | 2.16.840.1.114027.80.8.1.3 |Yes| OQS_OID_MLDSA44_ed25519
| mldsa44_p256 | 2.16.840.1.114027.80.8.1.4 |Yes| OQS_OID_MLDSA44_p256
| mldsa44_bp256 | 2.16.840.1.114027.80.8.1.5 |Yes| OQS_OID_MLDSA44_bp256
| mldsa65 | 1.3.6.1.4.1.2.267.12.6.5 |Yes| OQS_OID_MLDSA65
| p384_mldsa65 | 1.3.9999.7.3 |Yes| OQS_OID_P384_MLDSA65
| mldsa65_pss3072 | 2.16.840.1.114027.80.8.1.6 |Yes| OQS_OID_MLDSA65_pss3072
| mldsa65_rsa3072 | 2.16.840.1.114027.80.8.1.7 |Yes| OQS_OID_MLDSA65_rsa3072
| mldsa65_p256 | 2.16.840.1.114027.80.8.1.8 |Yes| OQS_OID_MLDSA65_p256
| mldsa65_bp256 | 2.16.840.1.114027.80.8.1.9 |Yes| OQS_OID_MLDSA65_bp256
| mldsa65_ed25519 | 2.16.840.1.114027.80.8.1.10 |Yes| OQS_OID_MLDSA65_ed25519
| mldsa87 | 1.3.6.1.4.1.2.267.12.8.7 |Yes| OQS_OID_MLDSA87
| p521_mldsa87 | 1.3.9999.7.4 |Yes| OQS_OID_P521_MLDSA87
| mldsa87_p384 | 2.16.840.1.114027.80.8.1.11 |Yes| OQS_OID_MLDSA87_p384
| mldsa87_bp384 | 2.16.840.1.114027.80.8.1.12 |Yes| OQS_OID_MLDSA87_bp384
| mldsa87_ed448 | 2.16.840.1.114027.80.8.1.13 |Yes| OQS_OID_MLDSA87_ed448
| falcon512 | 1.3.9999.3.11 |Yes| OQS_OID_FALCON512
| p256_falcon512 | 1.3.9999.3.12 |Yes| OQS_OID_P256_FALCON512
| rsa3072_falcon512 | 1.3.9999.3.13 |Yes| OQS_OID_RSA3072_FALCON512
| falconpadded512 | 1.3.9999.3.16 |Yes| OQS_OID_FALCONPADDED512
| p256_falconpadded512 | 1.3.9999.3.17 |Yes| OQS_OID_P256_FALCONPADDED512
| rsa3072_falconpadded512 | 1.3.9999.3.18 |Yes| OQS_OID_RSA3072_FALCONPADDED512
| falcon1024 | 1.3.9999.3.14 |Yes| OQS_OID_FALCON1024
| p521_falcon1024 | 1.3.9999.3.15 |Yes| OQS_OID_P521_FALCON1024
| falconpadded1024 | 1.3.9999.3.19 |Yes| OQS_OID_FALCONPADDED1024
| p521_falconpadded1024 | 1.3.9999.3.20 |Yes| OQS_OID_P521_FALCONPADDED1024
| sphincssha2128fsimple | 1.3.9999.6.4.13 |Yes| OQS_OID_SPHINCSSHA2128FSIMPLE
| p256_sphincssha2128fsimple | 1.3.9999.6.4.14 |Yes| OQS_OID_P256_SPHINCSSHA2128FSIMPLE
| rsa3072_sphincssha2128fsimple | 1.3.9999.6.4.15 |Yes| OQS_OID_RSA3072_SPHINCSSHA2128FSIMPLE
| sphincssha2128ssimple | 1.3.9999.6.4.16 |Yes| OQS_OID_SPHINCSSHA2128SSIMPLE
| p256_sphincssha2128ssimple | 1.3.9999.6.4.17 |Yes| OQS_OID_P256_SPHINCSSHA2128SSIMPLE
| rsa3072_sphincssha2128ssimple | 1.3.9999.6.4.18 |Yes| OQS_OID_RSA3072_SPHINCSSHA2128SSIMPLE
| sphincssha2192fsimple | 1.3.9999.6.5.10 |Yes| OQS_OID_SPHINCSSHA2192FSIMPLE
| p384_sphincssha2192fsimple | 1.3.9999.6.5.11 |Yes| OQS_OID_P384_SPHINCSSHA2192FSIMPLE
| sphincssha2192ssimple | 1.3.9999.6.5.12 |No| OQS_OID_SPHINCSSHA2192SSIMPLE
| p384_sphincssha2192ssimple | 1.3.9999.6.5.13 |No| OQS_OID_P384_SPHINCSSHA2192SSIMPLE
| sphincssha2256fsimple | 1.3.9999.6.6.10 |No| OQS_OID_SPHINCSSHA2256FSIMPLE
| p521_sphincssha2256fsimple | 1.3.9999.6.6.11 |No| OQS_OID_P521_SPHINCSSHA2256FSIMPLE
| sphincssha2256ssimple | 1.3.9999.6.6.12 |No| OQS_OID_SPHINCSSHA2256SSIMPLE
| p521_sphincssha2256ssimple | 1.3.9999.6.6.13 |No| OQS_OID_P521_SPHINCSSHA2256SSIMPLE
| sphincsshake128fsimple | 1.3.9999.6.7.13 |Yes| OQS_OID_SPHINCSSHAKE128FSIMPLE
| p256_sphincsshake128fsimple | 1.3.9999.6.7.14 |Yes| OQS_OID_P256_SPHINCSSHAKE128FSIMPLE
| rsa3072_sphincsshake128fsimple | 1.3.9999.6.7.15 |Yes| OQS_OID_RSA3072_SPHINCSSHAKE128FSIMPLE
| sphincsshake128ssimple | 1.3.9999.6.7.16 |No| OQS_OID_SPHINCSSHAKE128SSIMPLE
| p256_sphincsshake128ssimple | 1.3.9999.6.7.17 |No| OQS_OID_P256_SPHINCSSHAKE128SSIMPLE
| rsa3072_sphincsshake128ssimple | 1.3.9999.6.7.18 |No| OQS_OID_RSA3072_SPHINCSSHAKE128SSIMPLE
| sphincsshake192fsimple | 1.3.9999.6.8.10 |No| OQS_OID_SPHINCSSHAKE192FSIMPLE
| p384_sphincsshake192fsimple | 1.3.9999.6.8.11 |No| OQS_OID_P384_SPHINCSSHAKE192FSIMPLE
| sphincsshake192ssimple | 1.3.9999.6.8.12 |No| OQS_OID_SPHINCSSHAKE192SSIMPLE
| p384_sphincsshake192ssimple | 1.3.9999.6.8.13 |No| OQS_OID_P384_SPHINCSSHAKE192SSIMPLE
| sphincsshake256fsimple | 1.3.9999.6.9.10 |No| OQS_OID_SPHINCSSHAKE256FSIMPLE
| p521_sphincsshake256fsimple | 1.3.9999.6.9.11 |No| OQS_OID_P521_SPHINCSSHAKE256FSIMPLE
| sphincsshake256ssimple | 1.3.9999.6.9.12 |No| OQS_OID_SPHINCSSHAKE256SSIMPLE
| p521_sphincsshake256ssimple | 1.3.9999.6.9.13 |No| OQS_OID_P521_SPHINCSSHAKE256SSIMPLE

If [OQS_KEM_ENCODERS](CONFIGURE.md#OQS_KEM_ENCODERS) is enabled the following list is also available:

|Algorithm name |    default OID    | environment variable |
|---------------|:-----------------:|----------------------|
| frodo640aes | 1.3.9999.99.61 | OQS_OID_FRODO640AES
| p256_frodo640aes | 1.3.9999.99.60 | OQS_OID_P256_FRODO640AES
| x25519_frodo640aes | 1.3.9999.99.45 | OQS_OID_X25519_FRODO640AES
| frodo640shake | 1.3.9999.99.63 | OQS_OID_FRODO640SHAKE
| p256_frodo640shake | 1.3.9999.99.62 | OQS_OID_P256_FRODO640SHAKE
| x25519_frodo640shake | 1.3.9999.99.46 | OQS_OID_X25519_FRODO640SHAKE
| frodo976aes | 1.3.9999.99.65 | OQS_OID_FRODO976AES
| p384_frodo976aes | 1.3.9999.99.64 | OQS_OID_P384_FRODO976AES
| x448_frodo976aes | 1.3.9999.99.47 | OQS_OID_X448_FRODO976AES
| frodo976shake | 1.3.9999.99.67 | OQS_OID_FRODO976SHAKE
| p384_frodo976shake | 1.3.9999.99.66 | OQS_OID_P384_FRODO976SHAKE
| x448_frodo976shake | 1.3.9999.99.48 | OQS_OID_X448_FRODO976SHAKE
| frodo1344aes | 1.3.9999.99.69 | OQS_OID_FRODO1344AES
| p521_frodo1344aes | 1.3.9999.99.68 | OQS_OID_P521_FRODO1344AES
| frodo1344shake | 1.3.9999.99.71 | OQS_OID_FRODO1344SHAKE
| p521_frodo1344shake | 1.3.9999.99.70 | OQS_OID_P521_FRODO1344SHAKE
| kyber512 | 1.3.6.1.4.1.2.267.8.2.2 | OQS_OID_KYBER512
| p256_kyber512 | 1.3.9999.99.72 | OQS_OID_P256_KYBER512
| x25519_kyber512 | 1.3.9999.99.49 | OQS_OID_X25519_KYBER512
| kyber768 | 1.3.6.1.4.1.2.267.8.3.3 | OQS_OID_KYBER768
| p384_kyber768 | 1.3.9999.99.73 | OQS_OID_P384_KYBER768
| x448_kyber768 | 1.3.9999.99.50 | OQS_OID_X448_KYBER768
| x25519_kyber768 | 1.3.9999.99.51 | OQS_OID_X25519_KYBER768
| p256_kyber768 | 1.3.9999.99.52 | OQS_OID_P256_KYBER768
| kyber1024 | 1.3.6.1.4.1.2.267.8.4.4 | OQS_OID_KYBER1024
| p521_kyber1024 | 1.3.9999.99.74 | OQS_OID_P521_KYBER1024
| mlkem512 | 1.3.6.1.4.1.22554.5.6.1 | OQS_OID_MLKEM512
| p256_mlkem512 | 1.3.6.1.4.1.22554.5.7.1 | OQS_OID_P256_MLKEM512
| x25519_mlkem512 | 1.3.6.1.4.1.22554.5.8.1 | OQS_OID_X25519_MLKEM512
| mlkem768 | 1.3.6.1.4.1.22554.5.6.2 | OQS_OID_MLKEM768
| p384_mlkem768 | 1.3.9999.99.75 | OQS_OID_P384_MLKEM768
| x448_mlkem768 | 1.3.9999.99.53 | OQS_OID_X448_MLKEM768
| x25519_mlkem768 | 1.3.9999.99.54 | OQS_OID_X25519_MLKEM768
| p256_mlkem768 | 1.3.9999.99.55 | OQS_OID_P256_MLKEM768
| mlkem1024 | 1.3.6.1.4.1.22554.5.6.3 | OQS_OID_MLKEM1024
| p521_mlkem1024 | 1.3.9999.99.76 | OQS_OID_P521_MLKEM1024
| p384_mlkem1024 | 1.3.6.1.4.1.42235.6 | OQS_OID_P384_MLKEM1024
| bikel1 | 1.3.9999.99.78 | OQS_OID_BIKEL1
| p256_bikel1 | 1.3.9999.99.77 | OQS_OID_P256_BIKEL1
| x25519_bikel1 | 1.3.9999.99.56 | OQS_OID_X25519_BIKEL1
| bikel3 | 1.3.9999.99.80 | OQS_OID_BIKEL3
| p384_bikel3 | 1.3.9999.99.79 | OQS_OID_P384_BIKEL3
| x448_bikel3 | 1.3.9999.99.57 | OQS_OID_X448_BIKEL3
| bikel5 | 1.3.9999.99.82 | OQS_OID_BIKEL5
| p521_bikel5 | 1.3.9999.99.81 | OQS_OID_P521_BIKEL5
| hqc128 | 1.3.9999.99.84 | OQS_OID_HQC128
| p256_hqc128 | 1.3.9999.99.83 | OQS_OID_P256_HQC128
| x25519_hqc128 | 1.3.9999.99.58 | OQS_OID_X25519_HQC128
| hqc192 | 1.3.9999.99.86 | OQS_OID_HQC192
| p384_hqc192 | 1.3.9999.99.85 | OQS_OID_P384_HQC192
| x448_hqc192 | 1.3.9999.99.59 | OQS_OID_X448_HQC192
| hqc256 | 1.3.9999.99.88 | OQS_OID_HQC256
| p521_hqc256 | 1.3.9999.99.87 | OQS_OID_P521_HQC256
<!--- OQS_TEMPLATE_FRAGMENT_OIDS_END -->

# Key Encodings

By setting environment variables, oqs-provider can be configured to encode keys (subjectPublicKey and and privateKey ASN.1 structures) according to the following IETF drafts:

- https://datatracker.ietf.org/doc/draft-uni-qsckeys-dilithium/00/
- https://datatracker.ietf.org/doc/draft-uni-qsckeys-falcon/00/
- https://datatracker.ietf.org/doc/draft-uni-qsckeys-sphincsplus/00/

<!--- OQS_TEMPLATE_FRAGMENT_ENCODINGS_START -->
|Environment Variable | Permissible Values |
| --- | --- |
|`OQS_ENCODING_DILITHIUM2`|`draft-uni-qsckeys-dilithium-00/sk-pk`|
|`OQS_ENCODING_DILITHIUM3`|`draft-uni-qsckeys-dilithium-00/sk-pk`|
|`OQS_ENCODING_DILITHIUM5`|`draft-uni-qsckeys-dilithium-00/sk-pk`|
|`OQS_ENCODING_FALCON512`|`draft-uni-qsckeys-falcon-00/sk-pk`|
|`OQS_ENCODING_FALCONPADDED512`|`draft-uni-qsckeys-falcon-00/sk-pk`|
|`OQS_ENCODING_FALCON1024`|`draft-uni-qsckeys-falcon-00/sk-pk`|
|`OQS_ENCODING_FALCONPADDED1024`|`draft-uni-qsckeys-falcon-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHA2128FSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHA2128SSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHA2192FSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHA2192SSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHA2256FSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHA2256SSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHAKE128FSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHAKE128SSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHAKE192FSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHAKE192SSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHAKE256FSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
|`OQS_ENCODING_SPHINCSSHAKE256SSIMPLE`|`draft-uni-qsckeys-sphincsplus-00/sk-pk`|
<!--- OQS_TEMPLATE_FRAGMENT_ENCODINGS_END -->

By setting `OQS_ENCODING_<ALGORITHM>_ALGNAME` environment variables, the corresponding algorithm names are set. The names are documented in the [`qsc_encoding.h`](https://github.com/Quantum-Safe-Collaboration/qsc-key-encoder/blob/main/include/qsc_encoding.h) header file of the encoder library.

If no environment variable is set, or if an unknown value is set, the default is 'no' encoding, meaning that key serialization uses the 'raw' keys of the crypto implementations. If unknown values are set as environment variables, a run-time error will be raised.

The test script `scripts/runtests_encodings.sh` (instead of `scripts/runtests.sh`) can be used for a test run with all supported encodings activated.
