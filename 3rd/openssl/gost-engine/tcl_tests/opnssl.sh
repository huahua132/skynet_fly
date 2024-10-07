#!/bin/bash

export HSTNME=`hostname`

if test $HSTNME = tls-ref-cp10; then ossl=/usr/bin/openssl; fi
if test $HSTNME = tls-ref-cp20; then ossl=/opt/cryptopack2/bin/openssl; fi
if test $HSTNME = tls-ref-cp21; then ossl=/opt/cryptopack2/bin/openssl; fi

$ossl $*

exit $?
