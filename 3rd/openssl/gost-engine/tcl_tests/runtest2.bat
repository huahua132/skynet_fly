@echo off

rem Состав набора тестов
rem 1. Этот скрипт
rem 2. Файлы *.try
rem 3. Файлы *.tcl
rem 4. Файлы *.ciphers
rem 5. calcstat
rem 6. oidfile
rem 7. name2oid.tst

rem Пререквизиты, которые должны быть установлены на машине:
rem 1. tclsh.
rem 2. ssh (что характерно, называться должен именно так и не должен выводить
rem лишних сообщений), мы используем ssh.bat вокруг putty:
rem @plink -l build %*
rem Должен и настроен заход по ключам без пароля на lynx и все используемые
rem эталонники. Ключи этих машин должны быть в knownhosts с полными доменными 
rem именами серверов, то есть lynx.lan.cryptocom.ru и т.д. (для putty 
rem knownhosts хранятся в реесте).
rem В Firewall Windows необходимо прописать исключение, разрешающее 
rem соединения для программы openssl.exe. Внимание, Windows неправильно 
rem трактует понятие "локальная сеть" в описании исключения, нужно либо
rem выставлять "любой компьютер", либо явно задавать маску 10.51.0.0/255.255.0.0


IF "%OPENSSL_APP%"=="" set OPENSSL_APP=c:\cryptopack3\bin\openssl.exe
IF "%TCLSH%"=="" set TCLSH=c:\Tcl\bin\tclsh.exe

%TCLSH% getengine.tcl > engine_name.txt
set /p ENGINE_NAME= < engine_name.txt
del engine_name.txt

hostname > host_name.txt
set /p HOST_NAME= < host_name.txt
del host_name.txt
set TESTDIR=%HOST_NAME%-bat-%ENGINE_NAME%
rem emdir /s /q %TESTDIR%
rem mkdir %TESTDIR%
rem copy oidfile %TESTDIR%
set OTHER_VERSION=../OtherVersion

IF %ENGINE_NAME%==cryptocom (
		set BASE_TESTS=engine ssl dgst pkcs8 enc req-genpkey req-newkey ca smime smime2 smimeenc cms cms2 cmsenc pkcs12 nopath ocsp ts smime_io cms_io smimeenc_io cmsenc_io
		set OTHER_DIR=../%HOST_NAME%-bat-gost
) ELSE (
	IF %ENGINE_NAME%==gost (
		set BASE_TESTS=engine dgst pkcs8 enc req-genpkey req-newkey ca smime smime2 smimeenc cms cms2 cmsenc pkcs12 nopath ocsp ts ssl smime_io cms_io smimeenc_io cmsenc_io
		set OTHER_DIR=../%HOST_NAME%-bat-cryptocom
	) ELSE (
		echo No GOST providing engine found
		exit 1
	)
)

set PKCS7_COMPATIBILITY_TESTS=smime_cs cmsenc_cs cmsenc_sc
set CLIENT_TESTS=cp20 cp21
set WINCLIENT_TESTS=p1-1xa-tls1-v-cp36r4-srv p1-1xa-tls1-v-cp39-srv p1-1xa-tls1-v-cp4-01 p2-1xa-tls1-v-cp4-01 p2-2xa-tls1-v-cp4-12S p2-5xa-tls1-v-cp4-12L p1-1xa-tls1-v-cp4r3-01 p2-1xa-tls1-v-cp4r3-01 p2-2xa-tls1-v-cp4r3-01 p2-5xa-tls1-v-cp4r3-01 p1-1xa-tls1_1-v-cp4r3-01 p2-1xa-tls1_1-v-cp4r3-01 p2-2xa-tls1_1-v-cp4r3-01 p2-5xa-tls1_1-v-cp4r3-01 p1-1xa-tls1_2-v-cp4r3-01 p2-1xa-tls1_2-v-cp4r3-01 p2-2xa-tls1_2-v-cp4r3-01 p2-5xa-tls1_2-v-cp4r3-01 p1-1xa-tls1-v-cp5-01 p2-1xa-tls1-v-cp5-01 p2-2xa-tls1-v-cp5-01 p2-5xa-tls1-v-cp5-01 p1-1xa-tls1_1-v-cp5-01 p2-1xa-tls1_1-v-cp5-01 p2-2xa-tls1_1-v-cp5-01 p2-5xa-tls1_1-v-cp5-01 p1-1xa-tls1_2-v-cp5-01 p2-1xa-tls1_2-v-cp5-01 p2-2xa-tls1_2-v-cp5-01 p2-5xa-tls1_2-v-cp5-01
set SERVER_TESTS=cp20 cp21 csp36r4 csp39 csp4 csp4r3 csp5
set OPENSSL_DEBUG_MEMORY=on

rem eOR %%t IN (%BASE_TESTS%) DO %TCLSH% %%t.try
rem FOR %%t IN (%PKCS7_COMPATIBILITY_TESTS%) DO %TCLSH% %%t.try
FOR %%t IN (%SERVER_TESTS%) DO %TCLSH% server.try %%t
FOR %%t IN (%CLIENT_TESTS%) DO %TCLSH% client.try %%t
set CVS_RSH=ssh
FOR %%t IN (%WINCLIENT_TESTS%) DO %TCLSH% wcli.try %%t
IF EXIST %TESTDIR%\%OTHER_DIR% %TCLSH% interop.try
IF EXIST %TESTDIR%\%OTHER_VERSION% (
	set OTHER_DIR=%OTHER_VERSION%
	IF %ENGINE_NAME%==cryptocom (
		set ALG_LIST="gost2001:A gost2001:B gost2001:C" 
		set ENC_LIST="gost2001:A:1.2.643.2.2.31.3 gost2001:B:1.2.643.2.2.31.4 gost2001:C:1.2.643.2.2.31.2 gost2001:A:"
	) ELSE (
		set ALG_LIST="gost2001:A gost2001:B gost2001:C" 
		set ENC_LIST="gost2001:A:1.2.643.2.2.31.3 gost2001:B:1.2.643.2.2.31.4 gost2001:C:1.2.643.2.2.31.2 gost2001:A:"
	)
	%TCLSH% interop.try
)

%TCLSH% calcstat %TESTDIR%\stats %TESTDIR%\test.result
