# Security Policy

tlslite-ng received little-to-none 3rd party security review.

tlslite-ng **CANNOT** verify certificates – users of the library must use
external means to check if certificate of the peer is the expected one.

Because python execution environment uses hash tables to store variables (that
includes functions, objects and classes) it's very hard to create
implementations that are timing attack resistant. Additionally, all integers
use arbitrary precision arithmentic, so binary operations are data dependant
(see Hubert Kario
[blog post](https://securitypitfalls.wordpress.com/2018/08/03/constant-time-compare-in-python/)
on this topic). This means that CBC MAC-then-encrypt de-padding leaks timing
information and all pure python cipher implementations will leak timing
information. None of the included cipher implementations are written in a way
that even tries to hide the data dependance.

In other words, pure-python (tlslite-ng internal) implementations of all
ciphers, as well as all CBC mode ciphers working in MAC-then-encrypt mode are
**NOT** secure. Don't use them. In addition to that, use AEAD ciphersuites
(AES-GCM) or encrypt-then-MAC mode for CBC ciphers.

(Note: PyCrypto aes-gcm cipher is also not secure as it uses Python to
calculate GCM tag, see issue
[#301](https://github.com/tlsfuzzer/tlslite-ng/issues/301))

## Supported Versions

Only the current stable release is considered supported (will have fixes to
security issues backported and new patches will trigger a new release).

| Version | Supported          |
| ------- | ------------------ |
| 0.8.0-alpha | :x:                |
| 0.7.x   | :white_check_mark: |
| < 0.7   | :x:                |

## Reporting a Vulnerability

Security issues can be reported by sending an email to hkario@redhat.com.
Answer to the initial email can be expected in 2 work-days.

If an issue is recognised as a vulnerability, fixes for it will be developed
on a good faith basis.

Unless otherwise agreed to, we'd like to request the reporter to keep the
vulnerability confidential for the industry-accepted period for responsible
disclosure of 90 days. The period will be cut short if the fix is released
earlier.
