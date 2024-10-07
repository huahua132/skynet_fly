#!/bin/bash

OPENSSLDIR=`pwd`/../openssl
export LD_LIBRARY_PATH=$OPENSSLDIR
OPENSSL_CONF=`pwd`/engine.conf $GDB $OPENSSLDIR/apps/openssl $@
