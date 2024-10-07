#!/bin/sh

# Состав набора тестов
# 1. Этот скрипт
# 2. Файлы *.try
# 3. Файлы *.tcl
# 4. Файлы *.ciphers
# 5. calcstat
# 6. oidfile
# 7. name2oid.tst

# Пререквизиты, которые должны быть установлены на машине:
# 1. tclsh.  Может называться с версией (см. список версий ниже в цикле
# перебора)
# 2. ssh (что характерно, называться должен именно так). Должен быть
# настроен заход по ключам без пароля на lynx и все используемые эталонники.
# Ключи этих машин должны быть в knownhosts (с полными доменными именами
# серверов, то есть lynx.lan.cryptocom.ru и т.д.)
# 3. Под Windows скрипт выполняется в среде MinGW, при этом нужно "донастроить"
# ssh, а именно создать в разделе реестра
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
# DWORD-ключ DisableUserTOSSetting=0

CRYPTOPACK_MAIN_VERSION=3

if [ -n "$OPENSSL_LIBCRYPTO" ]; then
    libdir=`dirname $OPENSSL_LIBCRYPTO`
    # Linux, ELF HP-UX
    LD_LIBRARY_PATH=${libdir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
    export LD_LIBRARY_PATH
    # MacOS X
    DYLD_LIBRARY_PATH=${libdir}${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}
    export DYLD_LIBRARY_PATH
fi
: ${OPENSSL_APP:=$(which openssl 2>/dev/null)}
if [ -z "$OPENSSL_APP" ]; then
	if [ "$OS" != "Windows NT" -a "$OS" != "Windows_NT" ]; then
		if [ -x  /opt/cryptopack$CRYPTOPACK_MAIN_VERSION/bin/openssl ]; then
			OPENSSL_APP=/opt/cryptopack$CRYPTOPACK_MAIN_VERSION/bin/openssl
		elif [ -x /usr/local/cryptopack$CRYPTOPACK_MAIN_VERSION/bin/openssl ];then
			OPENSSL_APP=/usr/local/cryptopack$CRYPTOPACK_MAIN_VERSION/bin/openssl
		fi
	else
		if [ -x c:/cryptopack$CRYPTOPACK_MAIN_VERSION/bin/openssl.exe ] ; then
			OPENSSL_APP=c:/cryptopack$CRYPTOPACK_MAIN_VERSION/bin/openssl.exe
		fi
	fi
fi
if [ -z "$OPENSSL_APP" ]; then
	echo "openssl not found"
	exit 1
else
	echo "Using $OPENSSL_APP as openssl"
fi

: ${TCLSH:=$(which tclsh)}
if [ -z "$TCLSH" ]; then
	for version in "" 8.4 84 8.5 85 8.6 86; do
		for command in tclsh$version; do
			for dir in `echo "/opt/cryptopack/bin:$PATH" | sed -e 's/:/ /g'`; do
				echo "Checking $dir/$command"
				if [ -x $dir/$command ]; then
					TCLSH=$dir/$command
					break 3
				fi
			done
		done
	done
fi

if [ -z "$TCLSH" ]; then
	echo "tclsh not found in PATH, neither with nor without version, exiting"
	exit 2
else
	echo "Using $TCLSH as tclsh"
fi
TCLSH="$TCLSH -encoding utf-8"

echo "PWD: $PWD"
: ${OPENSSL_CONF:=$PWD/openssl-gost.cnf}
echo "OPENSSL_CONF: $OPENSSL_CONF"
export OPENSSL_CONF
echo "ENGINE_DIR: $ENGINE_DIR"
: ${OPENSSL_ENGINES:=$ENGINE_DIR}
echo "OPENSSL_ENGINES: $OPENSSL_ENGINES"
export OPENSSL_ENGINES
APP_SUFFIX=`basename $OPENSSL_APP .exe|sed s/openssl//`
[ -n "$OPENSSL_APP" ]&& export OPENSSL_APP
ENGINE_NAME=`$TCLSH getengine.tcl`
export ENGINE_NAME
[ -z "$TESTDIR" ] && TESTDIR=`pwd`
TESTDIR=${TESTDIR}/`hostname`-$ENGINE_NAME
[ -n "$APP_SUFFIX" ] && TESTDIR=${TESTDIR}-${APP_SUFFIX}
[ -d ${TESTDIR} ] && rm -rf ${TESTDIR}
mkdir -p ${TESTDIR}
cp oidfile ${TESTDIR}
export TESTDIR

case "$ENGINE_NAME" in
	gostkc3)
		BASE_TEST="1"
		;;
	cryptocom)
		BASE_TESTS="engine dgst mac pkcs8 enc req-genpkey req-newkey ca smime smime2 smimeenc cms cms2 cmsenc pkcs12 nopath ocsp ts ssl smime_io cms_io smimeenc_io cmsenc_io"
		OTHER_DIR=`echo $TESTDIR |sed 's/cryptocom/gost/'`
		;;
	gost)
		BASE_TESTS="engine dgst mac pkcs8 enc req-genpkey req-newkey ca smime smime2 smimeenc cms cms2 cmstc262019 cmsenc pkcs12 nopath ocsp ts ssl smime_io cms_io smimeenc_io cmsenc_io"
		OTHER_DIR=`echo $TESTDIR |sed 's/gost/cryptocom/'`
		;;
	*)
		echo "No GOST=providing engine found" 1>&2
		exit 1;
esac
if [ -x copy_param ];  then
	BASE_TESTS="$BASE_TESTS apache"
fi
PKCS7_COMPATIBILITY_TESTS="smime_cs cmsenc_cs cmsenc_sc"
SERVER_TESTS="cp20 cp21 csp36r4 csp39 csp4 csp4r3 csp5"
CLIENT_TESTS="cp20 cp21"
WINCLIENT_TESTS="p1-1xa-tls1-v-cp36r4-srv p1-1xa-tls1-v-cp39-srv p1-1xa-tls1-v-cp4-01 p2-1xa-tls1-v-cp4-01 p2-2xa-tls1-v-cp4-12S p2-5xa-tls1-v-cp4-12L p1-1xa-tls1-v-cp4r3-01 p2-1xa-tls1-v-cp4r3-01 p2-2xa-tls1-v-cp4r3-01 p2-5xa-tls1-v-cp4r3-01 p1-1xa-tls1_1-v-cp4r3-01 p2-1xa-tls1_1-v-cp4r3-01 p2-2xa-tls1_1-v-cp4r3-01 p2-5xa-tls1_1-v-cp4r3-01 p1-1xa-tls1_2-v-cp4r3-01 p2-1xa-tls1_2-v-cp4r3-01 p2-2xa-tls1_2-v-cp4r3-01 p2-5xa-tls1_2-v-cp4r3-01 p1-1xa-tls1-v-cp5-01 p2-1xa-tls1-v-cp5-01 p2-2xa-tls1-v-cp5-01 p2-5xa-tls1-v-cp5-01 p1-1xa-tls1_1-v-cp5-01 p2-1xa-tls1_1-v-cp5-01 p2-2xa-tls1_1-v-cp5-01 p2-5xa-tls1_1-v-cp5-01 p1-1xa-tls1_2-v-cp5-01 p2-1xa-tls1_2-v-cp5-01 p2-2xa-tls1_2-v-cp5-01 p2-5xa-tls1_2-v-cp5-01 p8k-5xa-tls1_2-v-cp5-01 p8k-2xa-tls1_2-v-cp5-01 p8m-5xa-tls1_2-v-cp5-01 p8m-2xa-tls1_2-v-cp5-01"
OPENSSL_DEBUG_MEMORY=on
export OPENSSL_DEBUG_MEMORY

fail=0
if [ "$*" ]; then
  for t do
    $TCLSH $t.try || fail=1
  done
  exit $fail
fi
for t in $BASE_TESTS; do
	if [ "$CI" ]; then
		if $TCLSH $t.try > $TESTDIR/$t.out 2>&1; then
			head -1 $TESTDIR/$t.out
		else
			fail=2
			cat $TESTDIR/$t.out
			echo "=== Output failures of $TESTDIR/$t.log ==="
			awk "/ ends failed/" RS= ORS='\n\n' $TESTDIR/$t.log |
				sed 's/^/\t/'
			echo "=== End of $TESTDIR/$t.log ==="
			exit 1
		fi
	else
		$TCLSH $t.try || fail=3
	fi
done

if false; then # ignore some tests for a time
ALG_LIST="rsa:1024 gost2001:XA gost2012_256:XA gost2012_512:A" $TCLSH ssl.try -clientconf $OPENSSL_CONF || fail=4
ALG_LIST="rsa:1024 gost2001:XA gost2012_256:XA gost2012_512:A" $TCLSH ssl.try -serverconf $OPENSSL_CONF || fail=5

for t in $PKCS7_COMPATIBILITY_TESTS; do
	$TCLSH $t.try || fail=6
done
for t in $SERVER_TESTS; do
	$TCLSH server.try $t || fail=7
done
for t in $CLIENT_TESTS; do
	$TCLSH client.try $t || fail=8
done
if [ -n "WINCLIENT_TESTS" ]; then
	if [ -z "$CVS_RSH" ]; then
		CVS_RSH=ssh
		export CVS_RSH
	fi
	for t in $WINCLIENT_TESTS; do
		$TCLSH wcli.try $t || fail=9
	done
fi
if [ -d $OTHER_DIR ]; then
	OTHER_DIR=../${OTHER_DIR} $TCLSH interop.try
fi
if [ -d OtherVersion ] ; then
	case "$ENGINE_NAME" in
		gostkc3)
			;;
		cryptocom)
			OTHER_DIR=../OtherVersion ALG_LIST="gost2001:A gost2001:B gost2001:C" ENC_LIST="gost2001:A:1.2.643.2.2.31.3 gost2001:B:1.2.643.2.2.31.4 gost2001:C:1.2.643.2.2.31.2 gost2001:A:" $TCLSH interop.try
			;;
		gost)
			OTHER_DIR=../OtherVersion ALG_LIST="gost2001:A gost2001:B gost2001:C" ENC_LIST="gost2001:A:1.2.643.2.2.31.3 gost2001:B:1.2.643.2.2.31.4 gost2001:C:1.2.643.2.2.31.2 gost2001:A:" $TCLSH interop.try
			;;
		*)
			echo "No GOST=providing engine found" 1>&2
			exit 1;
	esac
fi
fi # false
$TCLSH calcstat ${TESTDIR}/stats ${TESTDIR}/test.result
grep "leaked" ${TESTDIR}/*.log
if [ $fail  -ne 0 ]; then
	echo "Some tests FAILED, code $fail."
fi

exit $fail
