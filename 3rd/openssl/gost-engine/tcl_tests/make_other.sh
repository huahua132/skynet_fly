#!/bin/sh

# Создает подкаталог OtherVersion, копирует в него данные для тестирования
# совместимости с другими версиями.
# Данные берутся из результатов прогона тестов для открытого энжина 
# (поскольку именно он гарантированно умеет все нужные алгоритмы, 
# включая устаревшие).

TESTDIR=`hostname`-gost
SAVEDIR=OtherVersion
if ! [ -d ${TESTDIR} ]; then
	echo $TESTDIR does not exist.
	exit 1
fi 
[ -d ${SAVEDIR} ] && rm -fr ${SAVEDIR}
mkdir ${SAVEDIR}
cd ${TESTDIR}
cp -rp enc.enc enc.dat ../$SAVEDIR
cp -rp smimeCA test.crl test_crl_cacert.pem ../$SAVEDIR
cp -rp U_smime_* sign_*.msg ../$SAVEDIR
cp -rp cmsCA U_cms_* cms_sign_*.msg ../$SAVEDIR
cp -rp U_pkcs12_* ../$SAVEDIR
cp -rp encrypt.dat U_enc_* enc_*.msg ../$SAVEDIR
cp -rp U_cms_enc_* cms_enc_*.msg ../$SAVEDIR
