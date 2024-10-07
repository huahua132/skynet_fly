# Author: Anna Khaitovich (c) 2017
# see LICENCE file for legal information regarding use of this file

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.compat import a2b_base64, b2a_hex
from tlslite.utils.asn1parser import ASN1Parser
from tlslite.x509 import X509
from tlslite.ocsp import OCSPResponse, OCSPRespStatus, SingleResponse
from tlslite.utils.cryptomath import numberToByteArray, bytesToNumber


resp_OK = a2b_base64(str(
"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"
"p+YNJ+UJfB6ALag="
))
resp_malformed = a2b_base64("MAMKAQE=")
resp_internal = a2b_base64("MAMKAQI=")
resp_trylater = a2b_base64("MAMKAQM=")
resp_sigreq = a2b_base64("MAMKAQU=")
resp_unauthorized = a2b_base64("MAMKAQY=")
resp_nonext = a2b_base64(str(
"MIIBsAoBAKCCAakwggGlBgkrBgEFBQcwAQEEggGWMIIBkjB8ohYEFPW6BZQHpc7jISl5Z3Tq3X0p"
"dI9AGA8yMDE4MDExNzEzMzgyOVowUTBPMDowCQYFKw4DAhoFAAQUkBUkEUsQTCuZ8rp/mrdlULbf"
"yK4EFPW6BZQHpc7jISl5Z3Tq3X0pdI9AAgEBgAAYDzIwMTgwMTE3MTMzODI5WjANBgkqhkiG9w0B"
"AQUFAAOCAQEAgX46PdN6W6gLbOuWNwTHAwJ79agqjADHLtvYyISVCenKmaCMrhoe6jcutw1A4wz4"
"9BKfYqnO9AL1LYHOJ6ZPlzJx/nEiFue8HXb+ChiwG+nEhXprug+wP/APuKSOaKH2kcQf4Jtuv9cz"
"n/2PCaVmC+ErEThuGTZouT4eEIFMUGGDH+nZFHbl+DNm6R3+D7atOE1gDBO2LDJqIoZvaZTSpY+4"
"djZaiTdWAdOcUnnBhlhBvjg8nv6zxJ9ERBqm5P9cffnYVAJeGqylq/WFT/Ni6MprXgYoZq9bc7tk"
"PGGh5CnrOhcIQCUIX+ceM6ruxdraiPJALpY1gZz7SY53GQsXfg=="
))
resp_sig_sha1 = a2b_base64(str(
"MIIBxAoBAKCCAb0wggG5BgkrBgEFBQcwAQEEggGqMIIBpjCBj6IWBBTdieQsa8v7QTD1lfiA4LPa"
"pj5zpRgPMjAxODAzMjkxMDAxMDdaMGQwYjA6MAkGBSsOAwIaBQAEFJAVJBFLEEwrmfK6f5q3ZVC2"
"38iuBBTdieQsa8v7QTD1lfiA4LPapj5zpQIBAoAAGA8yMDE4MDMyOTEwMDEwN1qgERgPMjAxODAz"
"MzAxMDAxMDdaMA0GCSqGSIb3DQEBBQUAA4IBAQDB1RYVVpLGIWBZLftbEBwFRunGoGq5HEfFtmfd"
"0F3qwjIfqagtnnI8OrJuqkAt4G9/MvCWw3Hc6RHaqYGjzzJL/b2Qpwe6TuHk+pqeaJIiZctvjOhy"
"31cEj5CEz+Zh093diRw6YDjwD+UgirkkGl4VIqRUEwLdEHWQ+l7Se9cw9DEj2uM+MGaR3oUvrVt1"
"1a/vxtV1/Nr56kvN9lhMrNKB8rVfIwvpXJ2lQTPMi21fyNxiaY97rIeYd20TrbLQC6IblV51giTg"
"fL24fVZt8NAnGrho/lBhkbQ2JGcW9NmXWLZaHTUgDHS+3+Q0js8/CW9Ajouu0rClFnbeu4yn+Ffi"
))
cert_sig_sha1 = a2b_base64(str(
"MIIDKzCCAhOgAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQKDApFeGFt"
"cGxlIENBMCIYDzIwMTMwMzI5MTAwMTA1WhgPMjAyODAzMjkxMDAxMDVaMBUxEzAR"
"BgNVBAoMCkV4YW1wbGUgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB"
"AQDHTixwDQuDillTw6P5Q7ZtHcFXzmPL4Rnvybar2+iA73R20s37ufWWz9NMpjdv"
"zl7OnudvFwzgzcKyUmuarUV4nN1rcQ5TsEUrZy99f+GE2tpmObCKY707ZnQwxyB6"
"0CoKV8erXGiXe3ox5/HYVT6F1FeabrNNZK7YzhOOaJD64fDsL8LgeOZzEan30yvA"
"flKVu4yUSNzqlG1qh37F+yL8C2G3QdTS/7AnAmTiQaLIiW7564WWhZtbVIytqTVb"
"IpP3QfPMQr4enlpxKVq9TBMDEgDIBTrBN9crQrV7acrrp3CBcI3iYa0YAP1U0RK3"
"1W/uK0oL4jGTuaZv+F/uNfvnAgMBAAGjgYEwfzAPBgNVHRMBAf8EBTADAQH/MA4G"
"A1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQU3YnkLGvL+0Ew9ZX4gOCz2qY+c6UwPQYD"
"VR0jBDYwNIAU3YnkLGvL+0Ew9ZX4gOCz2qY+c6WhGaQXMBUxEzARBgNVBAoMCkV4"
"YW1wbGUgQ0GCAQEwDQYJKoZIhvcNAQELBQADggEBAAvGcqavDPo8s4Nm0ZRA0jvc"
"0GbPLIpYV+XUI11D6ma6lPJOPtyJdCWY3d+sdTX8A6zbSOKbpCFRzKyLw1GyPzrg"
"pczkoWVummukBtWCCB8ULpd28/Fn9g2I5WZoO3bXvza8Xl+LASWDuxi0EJTF64Z4"
"xZLKGRThfzWIWf11PVI9TIuUM9dJkteJAb8tUPohApVPNUU7LL74/pquZKaqubpS"
"8AgUY00SfS6lAQZK36yDxYDxgNZL/Wgmpxqjh6V+loh/75OvrYsuHPvdU2xHgVu4"
"pQ/6c/pH6rAIyunpQCwE35ekwwwDdRHLCw3dSfevQd/ucpa5zdWLSwuxRINL3Sc="
))
resp_sig_sha256 = a2b_base64(str(
"MIIBxAoBAKCCAb0wggG5BgkrBgEFBQcwAQEEggGqMIIBpjCBj6IWBBTLcv+aDVgOwqkCq4JTiC6f"
"klAqrRgPMjAxODAzMjcxMjAyNTBaMGQwYjA6MAkGBSsOAwIaBQAEFJAVJBFLEEwrmfK6f5q3ZVC2"
"38iuBBTLcv+aDVgOwqkCq4JTiC6fklAqrQIBAoAAGA8yMDE4MDMyNzEyMDI1MFqgERgPMjAxODAz"
"MjgxMjAyNTBaMA0GCSqGSIb3DQEBCwUAA4IBAQAtGmPvwG1hFJz1sL7EHGcm8qsnrYv4no3ylQVU"
"IMJuMgAPpRm1pKJ2hsdENc2KO/4QThLY0cxYIyr0l0aHOEtYgVKCkD9oPsn1aAYO1jhEFcAhmN5S"
"+dj5TdFWA1OI7Z0SH3UZTlb7hEHxhJ6PhTWb7RW2KtKTOhLy4kdgdt95oGM5IPncXXCP/4QEsQv1"
"NxTd05OT70GD15gjbx0LHYQKdqtHkrd8vLnxv3Ku4AgMWjlmu+VsbwgpDupCPZT7mVFCg7o01grV"
"/pRaqwSastU/RoWOO/aBbbZ/SLu2benEV8A/+WvXaHx/wWCJDMaort+EROi1pI5P/Mg4UHGdwcgj"
))
cert_sig_sha256 = a2b_base64(str(
"MIIDKzCCAhOgAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQKDApFeGFt"
"cGxlIENBMCIYDzIwMTMwMzI3MTIwMjQ3WhgPMjAyODAzMjcxMjAyNDdaMBUxEzAR"
"BgNVBAoMCkV4YW1wbGUgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB"
"AQDPnpQmVjVNk+AQ2DZvikBhOJFdqv7uDYTfvnKfWO+lDqAoA9wXC4/6jh4SDCgd"
"qPSgkjFTT3AH2JadPsHWPqG+PltE0pSk6iqCW57kzh/PBQFrVSHEjggvyjGI8Qgc"
"+0LW3zNP0rUL/OvAZhlptKIwW2wKpQPG3Pms+2qQ3Kg+uoRF5piw9KW65t1VKuOe"
"EYSN8mEgiTOE1PGbpAAyC144PN6cScb+21a066Ftk2b40prg9xugema4VM47+9IR"
"l+gvRmd27iq6dO+k6ZIO0YcMAF+r45UY8lMO92mL6rl3uLbDYMdMsMKKxZ9M+MA0"
"sytqFlLaURrhHqKQ76MxJ3xXAgMBAAGjgYEwfzAPBgNVHRMBAf8EBTADAQH/MA4G"
"A1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUy3L/mg1YDsKpAquCU4gun5JQKq0wPQYD"
"VR0jBDYwNIAUy3L/mg1YDsKpAquCU4gun5JQKq2hGaQXMBUxEzARBgNVBAoMCkV4"
"YW1wbGUgQ0GCAQEwDQYJKoZIhvcNAQELBQADggEBABQp8yDRKe5qoSySCwFRdelO"
"EytE2wdgmeOXa+Krx9CZqNcsnSQSYa1KPl72p2YPWkVhp5mnHJRg8NGIRQby/yb4"
"y2DTHkXLFl1r0eXfEvoMyGLuWkjinuqLQJrEyOjEapxGIbm9e1ZbzYeMd2SQg9Ll"
"BAGr/JMHzjTB3gvUziGXyUG0ZYVFBqKGYyUqcTl+0LoFNPQzQOWEaLzjbHTGA27N"
"0wjZf+jxGJN7HJNWpKE02AHGWNh+XXyJXMTCyE/osV1k1rHH9v5vEypBK6Rwj7rF"
"97NBvMJ9xxnTXCZIFr466Ec+FBSWTOnVSb3JOTHycrzTwY7o3QBqQh/KbxwnHHw="
))
#############################################################################
# for test_verify_cert_match
#############################################################################
server_cert = a2b_base64(str(
"MIIDLzCCAhegAwIBAgIBAzANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQKDApFeGFt"
"cGxlIENBMCIYDzIwMTgxMTA1MTMxNTM3WhgPMjAxOTExMDUxMzE1MzdaMBQxEjAQ"
"BgNVBAMMCWxvY2FsaG9zdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB"
"AL5Gl0xDPWU1WkyRDYqNM6T1/hYYShHHKfotZ16hIicd0hoqoTwUviRPhOzH6Fuz"
"Cq1t6cUzUesqH9q2sHnvuued7ANgsgbQ+fSMk+Pqbijqii7ZIfr+2at+a1B42Pr2"
"0buJaYQcNC2xFciQAnZOyCOFzQQMerfmteEKbO2AJ+8MTNACu3tKrEvB7bqckbjn"
"Gv7mFdr4uoaLl5q2OnW9FCWe8imtnTiByKZTRbThiOq3kq+eWqXCWVNL7K4qcGN2"
"6jUeSxisNIpRnfcFz1scJlfYiGcH5HIZhtVbcgavnsBLfqsMrjgEQ90rOu9tjM87"
"tveZxAh5JtExbq6nm9G5HvsCAwEAAaOBhjCBgzAOBgNVHQ8BAf8EBAMCA6gwEwYD"
"VR0lBAwwCgYIKwYBBQUHAwEwHQYDVR0OBBYEFIv7R1f7kCK+WpyNwd8KazfurcXU"
"MD0GA1UdIwQ2MDSAFN9ifpf006bRaeGKoV1vxXe5gE3ooRmkFzAVMRMwEQYDVQQK"
"DApFeGFtcGxlIENBggEBMA0GCSqGSIb3DQEBCwUAA4IBAQC515goTVqXLzkHoMYk"
"oS5cm4HNQBMioVhaNBTKBFnZrdJBP8Fe+e5/JMTBClhktyRjmR6zkNtje20kDV9d"
"WFf1OUtHWCjjDcLseeNkyvKdjZHZrXSkXtTaDYWPKOSaurvkY2sN+pHTNzfL9yfq"
"dHkSaMddBCU+Yrd2QRT93vgDIg3P9f1BpL1Uimesz3iH8/FCk/8X6PWXMntA2HY6"
"J/IByiLQfr7cFfpAd2yqHQVir0AT7ASGpQ/3+dwyG1qsK1VZbrw157Qmt47CVy7D"
"H+slATnjUzAENr0Uw41Up3HKH9Sy/O28yxSSb+/lkTNJ02/AtQ+lLkg8CrQwGgyu"
"YA79"
))
issuer_cert = a2b_base64(str(
"MIIDKzCCAhOgAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQKDApFeGFt"
"cGxlIENBMCIYDzIwMTMxMTA1MTMxMzU1WhgPMjAyODExMDUxMzEzNTVaMBUxEzAR"
"BgNVBAoMCkV4YW1wbGUgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB"
"AQDEnAVfDBjsC1TWUUIkCdn7+wGYnc5wfBBUG2QT4mfc5+rsAxfIGHEn3CyxvUZf"
"jYtHw3Up8DBUyDPb2OQngVWO7BEmdWNT1lGs05vk+DajHfZM4fs1r7n8t0yPOO1L"
"oHBojyvHLsFeiHiP0dUcvRYIOj/I5daNVga7A/SR5qnK5MvfDFPntrbRgI+VZ7hh"
"8AK7vcd2WQsun28hYWrvwvSRrwE33hHd5gTyp7t+x6YYBL7rRFV5hMTaQXJetXy+"
"bCWQz+4BFOGUkptqVWobyjoVixrFo2ZmDz4ulev+xEK3wq4MFc15RwKpWbij5UZv"
"6ax/XimrlGAnoWhIrpdCCmglAgMBAAGjgYEwfzAPBgNVHRMBAf8EBTADAQH/MA4G"
"A1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQU32J+l/TTptFp4YqhXW/Fd7mATegwPQYD"
"VR0jBDYwNIAU32J+l/TTptFp4YqhXW/Fd7mATeihGaQXMBUxEzARBgNVBAoMCkV4"
"YW1wbGUgQ0GCAQEwDQYJKoZIhvcNAQELBQADggEBABkmhBH2P8SqbP5BBMR4Lyva"
"sFW1LEjazLj7DpywDrWqWPJMmgQYCcFXhJD/m0gAaY9aP9TqhVdqJPrU393HegHj"
"daUuJ8ZG+VFmsoS3sl+dASU7QtccchNQ7wr/qCFGL3g1msNsUnZ2d/ka4u60aTzI"
"uhuVzKjA0/hJOnTURrTA0nhneyohhq7Y1mRIq3jbM21W5mk5vhZigXzDdjRpU+ZC"
"33XEjZrkU57nLUxVgWwJRfUG45/Svb83INf0Pf+pUyi1iIoI/aNBPSZc7vRDLaf5"
"gMMonOW4zwZiJ8Om2V1yVDjIvmoO19MexmODf2GhtmF8MI6iy20STjugQKMOQew="
))
other_issuer_cert = a2b_base64(str(
"MIIDKzCCAhOgAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQKDApFeGFt"
"cGxlIENBMCIYDzIwMTMxMTE5MDkxNDEzWhgPMjAyODExMTkwOTE0MTNaMBUxEzAR"
"BgNVBAoMCkV4YW1wbGUgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB"
"AQCxx4BwpfsExtUYpTLA6C3bGDOOjtfqYylP2p2RuKXSNr2/YVv/GCzVuCVJ0xa3"
"U7WHpXP4N7crqXu5M0ZzpfTm90IYX/P/Yf29P8fNWe878yRoWuRb52w79bszI+eL"
"lho/UV3LyIrwYLw9tHIO/IGWMAB4mpXsMqfAGkFpzL5bVy2QYQ9n+5yRZishGoq7"
"ZGS+BmzDij/eUb3yYWrA+62czhlMdeVIFudQeUSfxTPbZme7dvbhnrTCM8i70BuD"
"SxUZEFAb4rr1tiRDlc0Aw6XCLZVzjf/M2QhusYEmrc/KdkAkrd594qhN8ZOGuEf7"
"JtzVtMwLdCrQm5X1o9WoFLFnAgMBAAGjgYEwfzAPBgNVHRMBAf8EBTADAQH/MA4G"
"A1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUAvaHFpmkfiiw2+rXTGRW2MBXGdYwPQYD"
"VR0jBDYwNIAUAvaHFpmkfiiw2+rXTGRW2MBXGdahGaQXMBUxEzARBgNVBAoMCkV4"
"YW1wbGUgQ0GCAQEwDQYJKoZIhvcNAQELBQADggEBAIrm976D4jUh596GwHqEwNBa"
"z04qIythHJj8clBQKL6LMoF3BDi4FLJX9CfvyLa/ijIbVjOS7IDrPpPonfR60jv6"
"7s/b6iTAuzbhaMTSoTtoBc6z1L/KdH/FfQ+QFUEUaSwJ2J2LRJq7+jF3QMbHuF6y"
"15Yz5N+nARGVYurn0Dd6FD/wlTxsFU3iRcrd5s/uE2pXm8x9qtvDnQLGLFHpXcTM"
"87CfM0ZAA8OxRm3yudD/p1lxVQHyNcy13bz4g7Wd4hg0mTc9LZpuXyiDxdHJHdGU"
"QQXLWPfTf305OEp1Q6aXTVYLOJ1n45LqnsKnHHeIdibcYpFVqnPpQeQ0BYK2jxo="
))
other_server_cert = a2b_base64(str(
"MIIDLzCCAhegAwIBAgIBAjANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQKDApFeGFt"
"cGxlIENBMCIYDzIwMTgxMTE5MDkyMTM5WhgPMjAxOTExMTkwOTIxMzlaMBQxEjAQ"
"BgNVBAMMCWxvY2FsaG9zdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB"
"ALVwYLImFwbUH/fR1W0Y8QXBfl1zgXmT1gHAz2+T5WELVKaB9kfPX8PE8rtCLqDa"
"hdhKkgOaZcBAN5zx4Xdj8xxQG7TAkWsG9byPjJdPF3eqv47LHYZ9EZxWrI9KIxlW"
"zXDMxn3TkrVwYrSmYY5mkxzMvpOBZ3OjjM4El+Se1o+faW7gxSiMTEpFjHR4FhCE"
"VPNpGlGOKENPpk1ewv2zzEDbp6eglML36N8YPRjo4b4tAdBhzuy51kKOqMVQDbYs"
"VHd6/38/aUiYI6pCgByuxWfWV5JK1gG2w0TFriQNDxh7dGwYq7yYUpZ54CmexT+k"
"I/Tuvc+n0FRj1o4U/pfmgVECAwEAAaOBhjCBgzAOBgNVHQ8BAf8EBAMCA6gwEwYD"
"VR0lBAwwCgYIKwYBBQUHAwEwHQYDVR0OBBYEFOwvlnhcNb888Jm5pkXSGKcIg8e8"
"MD0GA1UdIwQ2MDSAFAL2hxaZpH4osNvq10xkVtjAVxnWoRmkFzAVMRMwEQYDVQQK"
"DApFeGFtcGxlIENBggEBMA0GCSqGSIb3DQEBCwUAA4IBAQCnmFeqiIT07U+ZUgcW"
"KtGJ1FvZUJaRxNSFcu6d+DDXr8pqB16DiK6DFH1poxzKZftBY2Ofsdh25s9TKRVi"
"CuGlPW05ieylDrmAx5jmUw68jSXxkIrftqKkg0SxAGtRQ9JRtPp54eyHPqSchB7+"
"BjLCZOoVE+4EN6xKsro+p0X80Qomr6vrK41gxtazyyu8DHgPJ3ixIhrGdFJjhWXd"
"xJuaPfYVOcg/R7NMCNOcpueOoeiTNVkW94tIw75rZVgeZbBUxBuVTEym8Zp5RYv4"
"+hE1weqtEGKQFXwy7P0y+MafANf8APCqjdOVuMtCkzGUydAW4Nc07e76ECR0iC+i"
"cSAw"
))
resps = a2b_base64(str(
"MIIFHgoBAKCCBRcwggUTBgkrBgEFBQcwAQEEggUEMIIFADCBpqEbMBkxFzAVBgNVBAMMDk9DU1Ag"
"UmVzcG9uZGVyGA8yMDE4MTEwNTEzNTMyOVowUTBPMDowCQYFKw4DAhoFAAQUkBUkEUsQTCuZ8rp/"
"mrdlULbfyK4EFN9ifpf006bRaeGKoV1vxXe5gE3oAgEDgAAYDzIwMTgxMTA1MTM1MzI5WqEjMCEw"
"HwYJKwYBBQUHMAECBBIEEElA4DXFxrDC6UM20+YPegEwDQYJKoZIhvcNAQELBQADggEBAJCViqVm"
"xxwNv+r7ix9UNcwHmbqthgHo8OIlAdJyBlsS+5DeM3aulWXLMSPs/irqWBkJOKdbeZUR6dCyoTJy"
"adwuAosqfDnhO+XYUtnRN2/jK/eyYxJnKT0cQlccGjDu6w29Kd6tcPAcjnZRGVXT9LpoB99mafEn"
"F+tC3CfrR+QNMueLeywded4yq53ppMAqLK5qqhzKaWgb4LJg8YvcCU8BK8c9Su4IBXugU8L7A9Xq"
"mGYLnXt4bVMeW6MH3yt8noDGva2YjReDKS9YbfOyjLndVLUXHfe0DqvzcrT1nZvNGdMharKAgMHK"
"HOKrz6E3VqgwU1itg7s80rYHFTTMTBmgggM/MIIDOzCCAzcwggIfoAMCAQICAQIwDQYJKoZIhvcN"
"AQELBQAwFTETMBEGA1UECgwKRXhhbXBsZSBDQTAiGA8yMDE4MTEwNTEzMTUyNVoYDzIwMTkxMTA1"
"MTMxNTI1WjAZMRcwFQYDVQQDDA5PQ1NQIFJlc3BvbmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEP"
"ADCCAQoCggEBAJrIsZnI9OgItz/EEpQvkr2Q2Na3bIty6/pB+61/a6xlftlgz6ksw8dhks5TEYHB"
"fkXSEqYSg7Stoi2UdsKLj7St3JQ4kZlU6TTXQiaG7BHr04MOFPcv+o2f09T9mgkJp8Tdq3xhi/7C"
"bif6p1AzSefZGxyFbb4WRQ+DzVoWOSwhXODtXoYSkiy/BzxggpZ9laamG63uQUYpuK03PGEbP4WW"
"G+m7NipfVYHwhetIvpgG1nL0RxBckmv0vrhGiwvIyFdTHySOuBvms5R5gXFazmibW7DkuRR0fLkp"
"PP/mAF8/Ze9paTfBtKmXe9ow7m9bIInstuujbozJvSsaZymecYECAwEAAaOBiTCBhjAOBgNVHQ8B"
"Af8EBAMCBsAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwkwHQYDVR0OBBYEFM4GUIgRdlSCQNm21Vry"
"0XfLWirEMD0GA1UdIwQ2MDSAFN9ifpf006bRaeGKoV1vxXe5gE3ooRmkFzAVMRMwEQYDVQQKDApF"
"eGFtcGxlIENBggEBMA0GCSqGSIb3DQEBCwUAA4IBAQBaSEtWpqXUW88MlVt+253HBn2Zggjpe6Sr"
"1ToI6V4ZkDIHb1o4PhW+BKD7D5iXcj5LapY3sduaPxmZBSu4gWYiDGH9ryR0q/BOmB7gH/2mZSMs"
"o13RpWRaF9mi2/VZTsmLqKvEr4AV3cZ49pw0xz1ba48DlP6tAuRYeSDz3/PGUcw8UBAJYvIBg8Kg"
"2vB/wufaEsTb++WvnN/IPOpIXDeZDKI+oaEjNjLWE5hsbaN0MOx8YDbtBF0LfCgQGMUaym7YkO/G"
"bnBwCAUb1LfCJ+qS+yl1mb47KUUWNCPGjHnk7gOo8C+wqmte1nz+3RTm/Dx6vvtTky176PQar5yQ"
"HeOK"
))
resps_sha256 = a2b_base64(str(
"MIIFOgoBAKCCBTMwggUvBgkrBgEFBQcwAQEEggUgMIIFHDCBwqEbMBkxFzAVBgNVBAMMDk9DU1Ag"
"UmVzcG9uZGVyGA8yMDE4MTEwNTE0MDU0MFowbTBrMFYwDQYJYIZIAWUDBAIBBQAEICuq+BZ90ynt"
"AEdF5YXexn1dHQnzwib8yGdrsPLXAkaXBCCOHziTMxVevxWJWq0/7BqAQaXuN8f+MZ18cnERcs6r"
"9AIBA4AAGA8yMDE4MTEwNTE0MDU0MFqhIzAhMB8GCSsGAQUFBzABAgQSBBBQzHGqI7aGUnypyYgx"
"Fr+ZMA0GCSqGSIb3DQEBCwUAA4IBAQAoIRmBMTgc8SozE0DS9+U1xQd8Yy1t9pZoSMOy2wEhxA43"
"U3URY0AASC65nDltZPhcSQYTYEc9XfGwna2oHOkBLRbh/WdZIOlAKWEKz229Vj9eFHueLJJn+5lQ"
"Km4sQbvsYHdk3uEvHPowzYLzBLCFMuGUrfQfkjoHGWFnCz0kIS5drG6t9N6x+Y/o5vH6iDpt/hyC"
"OKvsZNwiIpDDazqqGWJT6BBQ4N3YIYxW9NEG+DYDZGpHwh7l9wuLNFeQ95x5f0cAJ0gVvvrE4UTj"
"8id7+D2sJUddcdtb/8HN/5bsszOa47jqQmKvGx2f3Dso2uLtUYOVlO+mgSU4U8LQxcFGoIIDPzCC"
"AzswggM3MIICH6ADAgECAgECMA0GCSqGSIb3DQEBCwUAMBUxEzARBgNVBAoMCkV4YW1wbGUgQ0Ew"
"IhgPMjAxODExMDUxMzE1MjVaGA8yMDE5MTEwNTEzMTUyNVowGTEXMBUGA1UEAwwOT0NTUCBSZXNw"
"b25kZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCayLGZyPToCLc/xBKUL5K9kNjW"
"t2yLcuv6Qfutf2usZX7ZYM+pLMPHYZLOUxGBwX5F0hKmEoO0raItlHbCi4+0rdyUOJGZVOk010Im"
"huwR69ODDhT3L/qNn9PU/ZoJCafE3at8YYv+wm4n+qdQM0nn2RschW2+FkUPg81aFjksIVzg7V6G"
"EpIsvwc8YIKWfZWmphut7kFGKbitNzxhGz+FlhvpuzYqX1WB8IXrSL6YBtZy9EcQXJJr9L64RosL"
"yMhXUx8kjrgb5rOUeYFxWs5om1uw5LkUdHy5KTz/5gBfP2XvaWk3wbSpl3vaMO5vWyCJ7Lbro26M"
"yb0rGmcpnnGBAgMBAAGjgYkwgYYwDgYDVR0PAQH/BAQDAgbAMBYGA1UdJQEB/wQMMAoGCCsGAQUF"
"BwMJMB0GA1UdDgQWBBTOBlCIEXZUgkDZttVa8tF3y1oqxDA9BgNVHSMENjA0gBTfYn6X9NOm0Wnh"
"iqFdb8V3uYBN6KEZpBcwFTETMBEGA1UECgwKRXhhbXBsZSBDQYIBATANBgkqhkiG9w0BAQsFAAOC"
"AQEAWkhLVqal1FvPDJVbftudxwZ9mYII6Xukq9U6COleGZAyB29aOD4VvgSg+w+Yl3I+S2qWN7Hb"
"mj8ZmQUruIFmIgxh/a8kdKvwTpge4B/9pmUjLKNd0aVkWhfZotv1WU7Ji6irxK+AFd3GePacNMc9"
"W2uPA5T+rQLkWHkg89/zxlHMPFAQCWLyAYPCoNrwf8Ln2hLE2/vlr5zfyDzqSFw3mQyiPqGhIzYy"
"1hOYbG2jdDDsfGA27QRdC3woEBjFGspu2JDvxm5wcAgFG9S3wifqkvspdZm+OylFFjQjxox55O4D"
"qPAvsKprXtZ8/t0U5vw8er77U5Mte+j0Gq+ckB3jig=="
))
resps_sha512 = a2b_base64(str(
"MIIFfgoBAKCCBXcwggVzBgkrBgEFBQcwAQEEggVkMIIFYDCCAQWhGzAZMRcwFQYDVQQDDA5PQ1NQ"
"IFJlc3BvbmRlchgPMjAxODExMDUxNDAzMDFaMIGvMIGsMIGWMA0GCWCGSAFlAwQCAwUABEAUisDl"
"5ICvRJqHRsDgQOsSBEmzMxIoFvBAV0hRg4Haa8QyPFRmnrjeKx6+yxEuUHASFEblNdaNI9dPFd5U"
"TXRDBEAgfBJMqArXbQrl6iDNVbh4iseTJ3H7hNQXn/mbop0NTtsRu+ZPcPKox7C4b0S9yANVld64"
"pYHzBocCHfn4tc59AgEDgAAYDzIwMTgxMTA1MTQwMzAxWqEjMCEwHwYJKwYBBQUHMAECBBIEEFlz"
"HbmAyqb8o7kMLFW9KZ8wDQYJKoZIhvcNAQELBQADggEBAEKjqKerYxWAUhMxJKHYWDB0P+wTE74c"
"gVAXn1Qmd5vSP6hWy3Fuk6AAYHRxRRYBV5B+WKUE0q7SOeutYAyp2W3Nusne67tjSp5ivMpPOJ28"
"osS7s+8Rd1UIufTSenEurnRByeYbJfcKQWPurVUUUxx0f3vJczrLzpylE85k54nEaICAqMK5aDwD"
"5318mdBMJUNPqIuzU9yZnV7423p91EnY50xX3NEvCej7qQpWj8pAZ/WaWbm/g1ezxsqapAP1uwRe"
"cTnelyT3TpqDjMyF0Fq/5bZEehAuogOsapcqJUYQohi9yTYsrxya/KkWCy0zqyyXjxSkwB1kyWXf"
"33sz7eGgggM/MIIDOzCCAzcwggIfoAMCAQICAQIwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UECgwK"
"RXhhbXBsZSBDQTAiGA8yMDE4MTEwNTEzMTUyNVoYDzIwMTkxMTA1MTMxNTI1WjAZMRcwFQYDVQQD"
"DA5PQ1NQIFJlc3BvbmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJrIsZnI9OgI"
"tz/EEpQvkr2Q2Na3bIty6/pB+61/a6xlftlgz6ksw8dhks5TEYHBfkXSEqYSg7Stoi2UdsKLj7St"
"3JQ4kZlU6TTXQiaG7BHr04MOFPcv+o2f09T9mgkJp8Tdq3xhi/7Cbif6p1AzSefZGxyFbb4WRQ+D"
"zVoWOSwhXODtXoYSkiy/BzxggpZ9laamG63uQUYpuK03PGEbP4WWG+m7NipfVYHwhetIvpgG1nL0"
"RxBckmv0vrhGiwvIyFdTHySOuBvms5R5gXFazmibW7DkuRR0fLkpPP/mAF8/Ze9paTfBtKmXe9ow"
"7m9bIInstuujbozJvSsaZymecYECAwEAAaOBiTCBhjAOBgNVHQ8BAf8EBAMCBsAwFgYDVR0lAQH/"
"BAwwCgYIKwYBBQUHAwkwHQYDVR0OBBYEFM4GUIgRdlSCQNm21Vry0XfLWirEMD0GA1UdIwQ2MDSA"
"FN9ifpf006bRaeGKoV1vxXe5gE3ooRmkFzAVMRMwEQYDVQQKDApFeGFtcGxlIENBggEBMA0GCSqG"
"SIb3DQEBCwUAA4IBAQBaSEtWpqXUW88MlVt+253HBn2Zggjpe6Sr1ToI6V4ZkDIHb1o4PhW+BKD7"
"D5iXcj5LapY3sduaPxmZBSu4gWYiDGH9ryR0q/BOmB7gH/2mZSMso13RpWRaF9mi2/VZTsmLqKvE"
"r4AV3cZ49pw0xz1ba48DlP6tAuRYeSDz3/PGUcw8UBAJYvIBg8Kg2vB/wufaEsTb++WvnN/IPOpI"
"XDeZDKI+oaEjNjLWE5hsbaN0MOx8YDbtBF0LfCgQGMUaym7YkO/GbnBwCAUb1LfCJ+qS+yl1mb47"
"KUUWNCPGjHnk7gOo8C+wqmte1nz+3RTm/Dx6vvtTky176PQar5yQHeOK"
))

class TestOCSP(unittest.TestCase):
    def test_respOK(self):
        resp = OCSPResponse(resp_OK)
        self.assertEqual(OCSPRespStatus.successful, resp.resp_status)

    def test_malformedrequest(self):
        resp = OCSPResponse(resp_malformed)
        self.assertEqual(OCSPRespStatus.malformedRequest, resp.resp_status)
    
    def test_internalerror(self):
        resp = OCSPResponse(resp_internal)
        self.assertEqual(OCSPRespStatus.internalError, resp.resp_status)

    def test_trylater(self):
        resp = OCSPResponse(resp_trylater)
        self.assertEqual(OCSPRespStatus.tryLater, resp.resp_status)

    def test_sigrequired(self):
        resp = OCSPResponse(resp_sigreq)
        self.assertEqual(OCSPRespStatus.sigRequired, resp.resp_status)

    def test_unauthorized(self):
        resp = OCSPResponse(resp_unauthorized)
        self.assertEqual(OCSPRespStatus.unauthorized, resp.resp_status)

    def test_type_id_pkix_ocsp_basic(self):
        resp = OCSPResponse(resp_OK)
        self.assertEqual(bytearray([43, 6, 1, 5, 5, 7, 48, 1, 1]), resp.resp_type)

    def test_resp_id(self):
        resp = OCSPResponse(resp_OK)
        self.assertEqual(bytearray([4, 20, 156, 77, 0, 153, 0, 14, 139, 176, 1, 129, 
                                    117, 161, 186, 240, 208, 37, 215, 160, 28, 71]), 
                        resp.resp_id)
    
    def test_produced_at(self):
        resp = OCSPResponse(resp_OK)
        self.assertEqual(bytearray(b"20171113135112Z"), resp.produced_at)

    def test_signature_alg(self):
        resp = OCSPResponse(resp_OK)
        self.assertEqual(bytearray([42, 134, 72, 134, 247, 13, 1, 1, 11]), resp.signature_alg)

    def test_signature(self):
        resp = OCSPResponse(resp_OK)
        self.assertEqual(
            bytearray([0, 155, 245, 236, 104, 50, 168, 180, 30, 1, 17, 165, 12, 249, 208,
            100, 5, 234, 227, 182, 10, 206, 201, 197, 230, 163, 119, 85, 210, 121, 249,
            216, 250, 85, 86, 102, 230, 229, 82, 179, 208, 77, 208, 104, 228, 254, 85,
            140, 184, 5, 246, 184, 24, 204, 143, 30, 179, 188, 240, 20, 184, 79, 119, 50,
            230, 162, 207, 18, 167, 147, 163, 12, 61, 51, 228, 208, 234, 161, 26, 146, 25,
            12, 68, 43, 179, 144, 227, 192, 113, 240, 74, 15, 181, 87, 207, 7, 140, 43,
            242, 209, 219, 38, 218, 48, 104, 182, 12, 228, 155, 117, 53, 249, 178, 179,
            214, 173, 212, 127, 174, 171, 227, 92, 172, 219, 236, 251, 129, 208, 16, 198,
            71, 80, 201, 60, 242, 79, 48, 31, 119, 15, 125, 212, 2, 96, 149, 100, 221,
            246, 145, 157, 12, 132, 144, 0, 17, 95, 86, 45, 171, 98, 198, 18, 218, 10,
            247, 137, 201, 78, 92, 51, 250, 72, 73, 14, 216, 178, 190, 14, 223, 114, 80,
            91, 126, 227, 59, 44, 133, 93, 150, 40, 15, 4, 95, 55, 243, 140, 178, 237,
            111, 45, 137, 244, 104, 195, 243, 110, 48, 59, 248, 6, 0, 199, 32, 14, 136,
            228, 243, 210, 51, 144, 153, 140, 105, 185, 186, 190, 138, 137, 175, 203, 42,
            251, 188, 105, 188, 63, 223, 88, 127, 185, 246, 71, 221, 35, 100, 229, 116,
            97, 237, 208, 212, 126, 199, 12, 217, 196, 167]), 
            resp.signature)
    
    def test_verify_signature_sha1(self):
        resp = OCSPResponse(resp_sig_sha1)
        cert = X509()
        cert.parseBinary(cert_sig_sha1)
        self.assertTrue(resp.verify_signature(cert.publicKey))

    def test_verify_signature_sha256(self):
        resp = OCSPResponse(resp_sig_sha256)
        cert = X509()
        cert.parseBinary(cert_sig_sha256)
        self.assertTrue(resp.verify_signature(cert.publicKey))

    def test_invalid_signature(self):
        resp = OCSPResponse(resp_sig_sha1)
        cert = X509()
        cert.parseBinary(cert_sig_sha1)
        old_sig = resp.signature
        resp.signature = bytearray([0])
        self.assertNotEqual(resp.signature, old_sig)
        with self.assertRaises(ValueError) as ctx:
            resp.verify_signature(cert.publicKey)
        self.assertTrue("Signature could not be verified for sha1" in str(ctx.exception))

    def test_certs(self):
        resp = OCSPResponse(resp_OK)
        self.assertGreater(len(resp.certs), 0)
        cert = resp.certs[0]  # checking only first certificate
        self.assertIsInstance(cert, X509)

    def test_certs_signature(self):
        resp = OCSPResponse(resp_OK)
        self.assertGreater(len(resp.certs), 0)
        cert = resp.certs[0]  # checking only first certificate
        self.assertIsInstance(cert, X509)
        self.assertTrue(resp.verify_signature(resp.certs[0].publicKey))

class TestSingleResponse(unittest.TestCase):
    def setUp(self):
        self.server_cert = X509()
        self.server_cert.parseBinary(server_cert)
        self.issuer_cert = X509()
        self.issuer_cert.parseBinary(issuer_cert)

    def test_single_responses(self):
        resp = OCSPResponse(resp_OK)
        self.assertGreater(len(resp.responses), 0)
        for singleResp in resp.responses:
            self.assertEqual(bytearray(), singleResp.cert_status)

    def test_nonextupdate(self):
        resp = OCSPResponse(resp_nonext)
        self.assertGreater(len(resp.responses), 0)
        for singleResp in resp.responses:
            self.assertEqual(bytearray(), singleResp.cert_status)
            self.assertEqual(None, singleResp.next_update)

    def test_verify_cert_match(self):
        resp = OCSPResponse(resps)
        self.assertGreater(len(resp.responses), 0)
        for singleResp in resp.responses:
            verified = singleResp.verify_cert_match(self.server_cert,
                                                    self.issuer_cert)
            self.assertTrue(verified)

    def test_verify_cert_match_sha256(self):
        resp = OCSPResponse(resps_sha256)
        self.assertGreater(len(resp.responses), 0)
        for singleResp in resp.responses:
            verified = singleResp.verify_cert_match(self.server_cert,
                                                    self.issuer_cert)
            self.assertTrue(verified)

    def test_verify_cert_match_sha512(self):
        resp = OCSPResponse(resps_sha512)
        self.assertGreater(len(resp.responses), 0)
        for singleResp in resp.responses:
            verified = singleResp.verify_cert_match(self.server_cert,
                                                    self.issuer_cert)
            self.assertTrue(verified)

    def test_verify_cert_match_incorrect_issuer_cert(self):
        resp = OCSPResponse(resps)
        self.assertGreater(len(resp.responses), 0)
        # redefine issuer cert object
        self.issuer_cert.parseBinary(other_issuer_cert)
        for singleResp in resp.responses:
            with self.assertRaises(ValueError) as ctx:
                verified = singleResp.verify_cert_match(self.server_cert,
                                                        self.issuer_cert)
            self.assertEqual("Could not verify certificate public key",
                             str(ctx.exception))

    def test_verify_cert_match_incorrect_server_cert(self):
        resp = OCSPResponse(resps)
        self.assertGreater(len(resp.responses), 0)
        # redefine server cert object
        self.server_cert.parseBinary(other_server_cert)
        for singleResp in resp.responses:
            with self.assertRaises(ValueError) as ctx:
                verified = singleResp.verify_cert_match(self.server_cert,
                                                        self.issuer_cert)
            self.assertEqual("Could not verify certificate serial number",
                             str(ctx.exception))

if __name__ == '__main__':
    unittest.main()
