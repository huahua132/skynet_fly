import timeit

from tlslite.utils.cryptomath import gmpyLoaded, GMPY2_LOADED

print("Acceleration backends loaded:")
print("gmpy: {0}".format(gmpyLoaded))
print("gmpy2: {0}".format(GMPY2_LOADED))
print("")

def do(setup_statements, statement):
    # extracted from timeit.py
    t = timeit.Timer(stmt=statement, setup="\n".join(setup_statements))
    # determine number so that 0.2 <= total time < 2.0
    for i in range(1, 10):
        number = 10 ** i
        x = t.timeit(number)
        if x >= 0.2:
            break
    return x / number


prnt_form = (
    "{name:>16}{sep:1} {keygen:>9{form}}{unit:1} "
    "{keygen_inv:>9{form_inv}} {sign:>9{form}}{unit:1} "
    "{sign_inv:>9{form_inv}} {verify:>9{form}}{unit:1} "
    "{verify_inv:>9{form_inv}}"
)

print(
    prnt_form.format(
        keygen="keygen",
        keygen_inv="keygen/s",
        sign="sign",
        sign_inv="sign/s",
        verify="verify",
        verify_inv="verify/s",
        name="",
        sep="",
        unit="",
        form="",
        form_inv="",
    )
)

for size in [1024, 2048, 3072, 4096]:
    S1 = "from tlslite.utils.python_rsakey import Python_RSAKey"
    S2 = "from tlslite.utils.cryptomath import secureHash"
    S3 = "key = Python_RSAKey.generate(%s)" % size
    S4 = "msg = b'msg'"
    S5 = "msg_hash = secureHash(msg, 'sha1')"
    S6 = "sig = key.sign(msg_hash)"
    S7 = "key.verify(sig, msg_hash)"
    keygen = do([S1, S2], S3)
    sign = do([S1, S2, S3, S4, S5], S6)
    verf = do([S1, S2, S3, S4, S5, S6], S7)

    print(
        prnt_form.format(
            name="RSA {0} bits".format(size),
            sep=":",
            unit="s",
            keygen=keygen,
            keygen_inv=1.0 / keygen,
            sign=sign,
            sign_inv=1.0 / sign,
            verify=verf,
            verify_inv=1.0 / verf,
            form=".5f",
            form_inv=".2f",
        )
    )

print("")

