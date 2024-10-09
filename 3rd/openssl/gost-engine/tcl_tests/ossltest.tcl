#
# Расширение пакета test для OpenSSL
#
package require http
# Путь поиска пакета test
if {[info exists env(TOOLDIR)]} {
	lappend auto_path $env(TOOLDIR)
} {
	lappend auto_path "[file dirname [info script]]/../../maketool"
}


# outputs specified environment variables into log

proc log_vars {args} {
	foreach var $args {
		if [info exists ::env($var)] {
			log $var=$::env($var)
		} else {
			log "$var is not set"
		}	
	}
}	
# Проверка наличия необходимых переменных окружения
foreach var {OPENSSL_APP} {
if {![info exists env($var)]} {
	puts stderr "Environment variable $var not defined"
	exit 100
} else {
	set $var [file normalize $env($var)]
}
}

if {[info exists env(OPENSSL_CONF)]} {
	set OPENSSL_CONF $env(OPENSSL_CONF)
} else {
	if {[regexp {OPENSSLDIR: "([^\"]+)"} [exec $OPENSSL_APP version -d] => openssl_dir]} {
		set OPENSSL_CONF $openssl_dir/openssl.cnf
	} else {	
		puts stderr "Cannot find out default openssl config"
		exit 100
	}
}	

if {![file exists $OPENSSL_CONF]} {
	puts "Configuration file $OPENSSL_CONF doesn't exist"
	exit 100
}	

if {$::tcl_platform(platform) != "windows"} {
  proc kill {signal pid} {
  exec kill -$signal $pid
  }
} else {
  proc kill {signal pid} {
  exec taskkill /pid $pid /f
  }
}
	
package require test
set test::suffix ""
package require base64

#
# set  up test::src variable
#

if {[info exists env(TESTSRC)]} {
	set ::test::src [file normalize $env(TESTSRC)]
} else {
	set ::test::src [pwd]
}	

#
# set  up test::dir variable
#

if {[info exists env(TESTDIR)]} {
	set ::test::dir [file normalize $env(TESTDIR)]
} else {
	set ::test::dir [file join [pwd] z]
}	

#
# Фильтрует вывод полученный в виде длинной строки, разбивая на строки
# по \n. Возвращает строки, удовлетворяющие регулярному выражениу
# pattern
#

proc grep {pattern data} {
	set out ""
	foreach line [split $data "\n"] {
		if {[regexp $pattern $line]} {
			append out $line "\n"
		}
	}	
	return $out
}	
proc check_builtin_engine {} {
	global OPENSSL_APP
	set found [regexp Cryptocom [exec $OPENSSL_APP engine 2> /dev/null]]
	if {$found} {
		puts "Using statically compiled engine"
	} else {
		puts "Using dynamically loaded engine"
	}
	return $found
}	
	

# Вызывает команду openssl.
# Посылает в лог вывод на stdout и на stderr, возвращает его же.
proc openssl {cmdline} {
	global ENGINE_PATH OPENSSL_APP
	log_vars OPENSSL_CONF CRYPT_PARAMS RNG RNG_PARAMS CCENGINE_LICENSE
	if {[info exists ::test::engine]} {
		set cmdline [concat [lrange $cmdline 0 0] [list -engine $::test::engine] [lrange $cmdline 1 end]]
	}	
	log "OpenSSL cmdline: $OPENSSL_APP $cmdline"
	set f [open "|$OPENSSL_APP $cmdline" r]
	set output [read $f]
	if {[catch {close $f} msg]} {
		append output "STDERR CONTENTS:\n$msg"
		log $output
		if {[lindex $::errorCode 0]!="NONE"} {
			return -code error -errorcode $::errorCode $output
		}
	}	
	return $output
}	


proc getConfig {args} {
	global OPENSSL_CONF
	if {![info exists OPENSSL_CONF]} {
	  if {![regexp "OPENSSLDIR: \"\[^\"\]+\"" [openssl version -d] => openssl_dir]} {
	  	puts stderr "Cannot find out openssl directory"
		exit 1
	  }
	 set OPENSSL_CONF  "$openssl_dir/openssl.cnf"
	}
	set f [open $OPENSSL_CONF r]
	set out ""
	set mode copy
	while {[gets $f line]>=0} {
		if {[regexp	"\\s*\\\[\\s*(\\S+)\\s*\\\]" $line => section]} {
			if {[lsearch -exact $args $section]!=-1} {
				set mode skip
			} else {
				set mode copy
			}
		}
		if {$mode eq "copy"} {
			append out $line \n
		}	
	 }	
	 return $out
}	 
#
# Создает тестовый CA
# Допустимые параметры: 
# CAname - директория, в которой создается CA (testCA по умолчанию)
# алгоритм с параметрами в формате команды req
#

proc makeCA {{CAname {}} {algor_with_par gost2012_512:A}} {
	global OPENSSL_CONF
	if {![string length $CAname]} {
		set CAname [file rootname [file tail $::argv0]]CA-2012
	}	
	set test::ca $CAname
	file delete -force $CAname
	file mkdir $CAname
	makeFile $CAname/ca.conf "
\[ ca \]
default_ca      = CA_default            # The default ca section

\[ CA_default \]

dir            = [file join [pwd] $CAname]              # top dir
database       = \$dir/index.txt        # index file.
new_certs_dir  = \$dir/newcerts         # new certs dir

certificate    = \$dir/cacert.pem       # The CA cert
serial         = \$dir/serial           # serial no file
private_key    = \$dir/private/cakey.pem# CA private key
RANDFILE       = \$dir/private/.rand    # random number file

default_days   = 3650                  # how long to certify for
default_crl_days= 30                   # how long before next CRL
default_md     = default               # use digest corresponding the algorithm
default_startdate = 060101000000Z

policy         = policy_any            # default policy
email_in_dn    = yes                   #  add the email into cert D


nameopt        = ca_default            # Subject name display option
certopt        = ca_default            # Certificate display option
copy_extensions = copy                 # Copy extensions from requ


\[ policy_any \]
countryName            = supplied
stateOrProvinceName    = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = supplied

"	
	makeFile $CAname/req.conf "
\[req\]
prompt=no
distinguished_name = req_dn
\[ req_dn \]
C = RU
L = Moscow
CN=Test CA $algor_with_par
O=Cryptocom
OU=OpenSSL CA
emailAddress = openssl@cryptocom.ru
\[ v3_ca \]
# Extensions for a typical CA
# PKIX recommendation.
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true

# Key usage: this is typical for a CA certificate. However since it will
# prevent it being used as an test self-signed certificate it is best
# left out by default.
# keyUsage = cRLSign, keyCertSign

# Include email address in subject alt name: another PKIX recommendation
# subjectAltName=email:copy
# Copy issuer details
# issuerAltName=issuer:copy

# DER hex encoding of an extension: beware experts only!
# obj=DER:02:03
# Where 'obj' is a standard or added object
# You can even override a supported extension:
# basicConstraints= critical, DER:30:03:01:01:FF
"
	file mkdir $CAname/private
	file mkdir $CAname/newcerts
	generate_key [keygen_params $algor_with_par] $CAname/private/cakey.pem
	openssl "req -new  -x509 -key $CAname/private/cakey.pem -nodes -out $CAname/cacert.pem -config $CAname/req.conf -reqexts v3_ca -set_serial 0x11E"
	makeFile ./$CAname/.rand 1234567890
	makeFile ./$CAname/serial 011E
	makeFile ./$CAname/index.txt ""
	return [file isfile $CAname/cacert.pem]
}

proc extract_oids {filename {format PEM} {offset 0}} {
	set out ""
	if {$offset} {
		set miscargs "-offset $offset "
	} else {
		set miscargs ""
	}	
	foreach line [split [openssl "asn1parse $miscargs-in $filename -inform $format -oid oidfile"] "\n"] {
		if {([regexp {Gost\d+} $line]||[regexp "GostR" $line]||[regexp "GOST" $line]||[regexp "sha1" $line]) && ![regexp ^Loaded: $line]} {
			regsub {[^:]+:[^:]+:} $line "" line
			append out $line "\n"
		}
	}
	return $out
}
# 
# Формирует список параметров для openssl req необходимый для формирования 
# ключа c указанным алгоритмом и параметрами
#  
proc keygen_params {alg} {	
	return [split $alg :] 
}	

proc generate_key {params filename} {
	set alg [lindex $params 0]
	set param [lindex $params 1]
	set keyname $alg
	set keyname [append keyname _ $param .pem] 
	switch -glob $alg {
	rsa { 
		if {![string length $param]} {
			set param 1024
			set keyname "rsa_1024.pem"
		}
		set optname "-algorithm rsa -pkeyopt rsa_keygen_bits:$param"
		}
	ec {set optname "-paramfile $param"}
	dsa {set optname "-paramfile $param" }
	gost* { set optname "-algorithm $alg -pkeyopt paramset:$param" }
	}	
	if {$::tcl_platform(platform) eq "windows"} {
		set exesuffix ".exe"
	} else {
		set exesuffix ""
	}
	log "Keyname is $keyname"
#	if {[engine_name] eq "open"} {
		log "Calling openssl cmd to create private key"
		openssl "genpkey  $optname -out $filename"
#	} elseif {[info exists ::env(OBJ)] && [file executable ../$::env(OBJ)/keytest$exesuffix]&& $alg eq "gost2001"} {
#		log "keytest$exesuffix $alg $param $filename"
#		exec ../$::env(OBJ)/keytest$exesuffix $alg $param $filename >&@ stdout
#	} elseif {[info exists ::env(OBJ)] && [file executable ../$::env(OBJ)/keytest$exesuffix]&& $alg eq "gost2012_256"} {
#		log "keytest$exesuffix $alg $param $filename"
#		exec ../$::env(OBJ)/keytest$exesuffix $alg $param $filename >&@ stdout
#	} elseif {[info exists ::env(OBJ)] && [file executable ../$::env(OBJ)/keytest$exesuffix]&& $alg eq "gost2012_512"} {
#		log "keytest$exesuffix $alg $param $filename"
#		exec ../$::env(OBJ)/keytest$exesuffix $alg $param $filename >&@ stdout
#	} elseif {[info exists ::env(PRIVATEKEYSDIR)] && [file exists $::env(PRIVATEKEYSDIR)/$keyname]} {
#		log "Copying file $keyname"
#		file copy $::env(PRIVATEKEYSDIR)/$keyname $filename
#	} else {
#		log "Calling openssl cmd to create private key"
#		openssl "genpkey  $optname -out $filename"
#	}
}

#
# Создает тестового пользователя с одним ключом подписи и одной заявкой
# на сертификат. 
# Параметры 
# username Имя директории, куда складывать файлы этого пользователя
# alg Параметр для опции -newkey команды openssl req, задающий алгоритм
#  ключа и параметры этого алгоритма
# Последующие параметры имеют вид списка ключ значение и задают поля
# Distinguished Name 
# FIXME Процедуру надо поправить, чтобы работала с новой версией openssl
proc makeUser {username alg args} {
	file delete -force $username
	file mkdir $username
	if {[lsearch $args CN]==-1} {
		lappend args CN $username
	}	
	makeFile $username/req.conf [eval makeConf $args]
	log "req.conf --------\n[getFile $username/req.conf]-------------"
	
	generate_key [keygen_params $alg] $username/seckey.pem
	openssl "req -new -key $username/seckey.pem -nodes -out $username/req.pem -config $username/req.conf"
	return [expr {[file size $username/req.pem] > 0}]
}

proc makeSecretKey {username alg} {
	file delete -force $username
	file mkdir $username
	generate_key [keygen_params $alg] $username/seckey.pem	
	return [expr {[file size $username/seckey.pem] > 0}]
}

#
# Создает пользователя с помощью makeUser и подписывает его сертификат
# ключом ранее созданного testCA. 
# Параметр CAname обрабатывается специальным образом: он не попадает в DN
#
proc makeRegisteredUser {username alg args } {
	if {![info exists params(CAname)]&&![info exists ::test::ca]} {
		return -code error "Default CA name is not known. Have you called makeCA earlier in this script?"
	}	
	set CAname $test::ca
	array set params $args
	if {[info exist params(CAname)]} {
		set CAname $params(CAname)
		unset params(CAname)
	}
	if {![file isdirectory $CAname]||![file exists $CAname/cacert.pem]} {
		return -code error "CA $CAname doesn't exists"
	}	
	eval makeUser [list $username $alg] [array get params]
	openssl "ca -config $CAname/ca.conf -in $username/req.pem -out $username/cert.pem -batch -notext" 
	return [file isfile $username/cert.pem]
}

proc makeConf {args} {
	global OPENSSL_CONF
	array set dn_attrs [list C  RU\
	L  Moscow\
	CN "Dummy user"\
	O Cryptocom\
	OU "OpenSSL Team"\
	emailAddress  "openssl@cryptocom.ru"\
	]
	array set dn_attrs $args
	if {[info exists dn_attrs(extensions)]} {
		set extensions $dn_attrs(extensions)
		unset dn_attrs(extensions)
	}	
	set out ""
	append out {[req]
prompt=no
distinguished_name = req_dn
}
if {[info exists extensions]} {
	append out "req_extensions = req_exts\n\[ req_exts \]\n" $extensions "\n"
}	
append out "\[ req_dn \]\n"
	foreach {key val} [array get dn_attrs] {
		append out "$key=$val\n"
	}
	return $out
}	
#
# Выполняет замену регулярного выражения re на строку s в указанном
# PEM-документе.
#
proc hackPem {re pem s} {
	set out ""
	foreach {whole_pem start_line coded_body end_line} [regexp -inline -all "(-----BEGIN \[^\n\]+-----\n)(.*?)(\n-----END \[^\n\]+-----\n)" $pem] {
		set der [::base64::decode $coded_body]
		set der [regsub -all $re $der $s]
		append out $start_line [::base64::encode $der] $end_line
	}
	return $out
}	

#
# Handling of OIDs
#

source [file dirname  [info script]]/name2oid.tcl
foreach {name oid} [array get name2oid] {
	set oid2name($oid) $name
}

proc long_name_by_id {id} {
	variable name2oid
	variable oid2name
	if {[regexp {^\d+(\.\d+)+$} $id]} {
	return "GOST $oid2name($id) $id"
	}
	return "GOST $id $name2oid($id)"
}

proc alg_id {alg} {
	switch -glob $alg {
		gost94cc {return pk_sign94_cc}
		gost94cc:* {return pk_sign94_cc}
		gost94:* {return pk_sign94_cp}
		gost2001cc:* {return pk_sign01_cc}
		gost2001cc {return pk_sign01_cc}
		gost2001:* {return pk_sign01_cp}
		gost2012_256:* {return pk_sign12_256}
		gost2012_512:* {return pk_sign12_512}
	}
}

proc alg_with_digest {alg} {
	variable name2oid
	switch -glob $alg {
		gost94cc {return hash_with_sign94_cc}
		gost94cc:* {return hash_with_sign94_cc}
		gost94:* {return hash_with_sign94_cp}
		gost2001cc:* {return hash_with_sign01_cc}
		gost2001cc {return hash_with_sign01_cc}
		gost2001:* {return hash_with_sign01_cp}
		gost2012_256:* {return hash_with_sign12_256}
		gost2012_512:* {return hash_with_sign12_512}
		
	}
}

proc alg_long_name {alg} {
	variable name2oid
	switch -glob $alg {
		#gost94cc {return hash_with_sign94_cc}
		#gost94cc:* {return hash_with_sign94_cc}
		#gost94:* {return hash_with_sign94_cp}
		#gost2001cc:* {return hash_with_sign01_cc}
		#gost2001cc {return hash_with_sign01_cc}
		gost2001:* {return "GOST R 34.10-2001"}
		gost2012_256:* {return "GOST R 34.10-2012 with 256 bit modulus"}
		gost2012_512:* {return "GOST R 34.10-2012 with 512 bit modulus"}
	}
}

# Returns hash algorithm corresponded to sign algorithm
proc alg_hash {alg} {
    switch -glob $alg {
        gost2012_256:* {return hash_12_256}
        gost2012_512:* {return hash_12_512}
        * {return hash_94}
   }
}

# Returns short name of hash algorithm
proc hash_short_name {hash_alg} {
    switch -glob $hash_alg {
        *hash_94 {return md_gost94}
        hash_12_256 {return md_gost12_256}
        hash_12_512 {return md_gost12_512}
        default {return $hash_alg}
    }
}

proc ts_hash_long_name {hash_alg} {
    switch -glob $hash_alg {
        *hash_94 {return md_gost94}
        hash_12_256 {return md_gost12_256}
        hash_12_512 {return md_gost12_512}
        default {return $hash_alg}
    }
}

# Returns long name of hash algorithm
proc hash_long_name {hash_alg} {
    switch -glob $hash_alg {
		*hash_94* {return "GOST R 34.11-94"}
		gost2001* {return "GOST R 34.11-94"}
        *12_256* {return "GOST R 34.11-2012 with 256 bit hash"}
        *12_512* {return "GOST R 34.11-2012 with 512 bit hash"}
        default {return $hash_alg}
    }
}

# Returns long name of hash_with_sign algorithm
proc hash_with_sign_long_name {alg} {
    switch -glob $alg {
        gost2001:* {return "GOST R 34.11-94 with GOST R 34.10-2001"}
        gost2012_256:* {return "GOST R 34.10-2012 with GOST R 34.11-2012 (256 bit)"}
        gost2012_512:* {return "GOST R 34.10-2012 with GOST R 34.11-2012 (512 bit)"}
        default {return $alg}
    }
}

proc smime_hash_with_sign_long_name {alg} {
    switch -glob $alg {
        hash_with_sign01_cp {return "GOST R 34.11-94 with GOST R 34.10-2001"}
        hash_with_sign12_256 {return "GOST R 34.10-2012 with GOST R 34.11-2012 (256 bit)"}
        hash_with_sign12_512 {return "GOST R 34.10-2012 with GOST R 34.11-2012 (512 bit)"}
        default {return $alg}
    }
}

proc micalg {hash_alg} {
    switch -exact $hash_alg {
        hash_94 {return "gostr3411-94"}
        hash_12_256 {return "gostr3411-2012-256"}
        hash_12_512 {return "gostr3411-2012-512"}
    }
}

proc param_pubkey {alg} {
	variable name2oid
	switch -exact $alg {
		gost94cc: {return param_pubkey94_cpa}
		gost94cc {return param_pubkey94_cpa}
		gost94:A {return param_pubkey94_cpa}
		gost94:B {return param_pubkey94_cpb}
		gost94:C {return param_pubkey94_cpc}
		gost94:D {return param_pubkey94_cpd}
		gost94:XA {return param_pubkey94_cpxcha}
		gost94:XB {return param_pubkey94_cpxchb}
		gost94:XC {return param_pubkey94_cpxchc}
		gost2001cc: {return param_pubkey01_cc}
		gost2001cc {return param_pubkey01_cc}
		gost2001:0 {return param_pubkey01_cptest}
		gost2001:A {return param_pubkey01_cpa}
		gost2001:B {return param_pubkey01_cpb}
		gost2001:C {return param_pubkey01_cpc}
		gost2001:XA {return param_pubkey01_cpxcha}
		gost2001:XB {return param_pubkey01_cpxchb}
		gost2012_256:0 {return param_pubkey01_cptest}
		gost2012_256:A {return param_pubkey01_cpa}
		gost2012_256:B {return param_pubkey01_cpb}
		gost2012_256:C {return param_pubkey01_cpc}
		gost2012_256:XA {return param_pubkey01_cpxcha}
		gost2012_256:XB {return param_pubkey01_cpxchb}
		gost2012_512:0 {return param_pubkey12_512_0}
		gost2012_512:A {return param_pubkey12_512_A}
		gost2012_512:B {return param_pubkey12_512_B}
	}
}


proc param_hash_long_name {hash_alg {pk_alg {}}} {
    # R 1323565.1.023-2018 (5.2.1.2) not recommends or forbids encoding
    # hash oid into TC26 (2012) parameters in AlgorithmIdentifier, so
    # this is removed.
    # Note:
    # Commit d47b346 reverts this behavior for 512-bit 0,A,B parameters
    switch -glob $pk_alg {
	gost2012_256:TC* {return}
	gost2012_512:C {return}
    }
    switch -glob $hash_alg {
        *hash_94 {return "id-GostR3411-94-CryptoProParamSet"}
        hash_12_256 {return "GOST R 34.11-2012 with 256 bit hash"}
        hash_12_512 {return "GOST R 34.11-2012 with 512 bit hash"}
    }
}

proc pubkey_long_name {alg} {
	variable name2oid
	switch -glob $alg {
		
		#gost2001cc: {return param_pubkey01_cc}
		#gost2001cc {return param_pubkey01_cc}
		#gost2001:0 {return param_pubkey01_cptest}
		gost2001:A {return "id-GostR3410-2001-CryptoPro-A-ParamSet"}
		gost2001:B {return "id-GostR3410-2001-CryptoPro-B-ParamSet"}
		gost2001:C {return "id-GostR3410-2001-CryptoPro-C-ParamSet"}
		gost2001:XA {return "id-GostR3410-2001-CryptoPro-XchA-ParamSet"}
		gost2001:XB {return "id-GostR3410-2001-CryptoPro-XchB-ParamSet"}
		gost2012_256:0 {return "id-GostR3410-2001-TestParamSet"}
		gost2012_256:A {return "id-GostR3410-2001-CryptoPro-A-ParamSet"}
		gost2012_256:B {return "id-GostR3410-2001-CryptoPro-B-ParamSet"}
		gost2012_256:C {return "id-GostR3410-2001-CryptoPro-C-ParamSet"}
		gost2012_256:XA {return "id-GostR3410-2001-CryptoPro-XchA-ParamSet"}
		gost2012_256:XB {return "id-GostR3410-2001-CryptoPro-XchB-ParamSet"}
		gost2012_256:TCA {return "GOST R 34.10-2012 (256 bit) ParamSet A"}
		gost2012_256:TCB {return "GOST R 34.10-2012 (256 bit) ParamSet B"}
		gost2012_256:TCC {return "GOST R 34.10-2012 (256 bit) ParamSet C"}
		gost2012_256:TCD {return "GOST R 34.10-2012 (256 bit) ParamSet D"}
		#gost2012_512:0 {return param_pubkey12_512_0}
		gost2012_512:A {return 	"GOST R 34.10-2012 (512 bit) ParamSet A"}
		gost2012_512:B {return 	"GOST R 34.10-2012 (512 bit) ParamSet B"}
		gost2012_512:C {return  "GOST R 34.10-2012 (512 bit) ParamSet C"}
	}
}

proc mkObjList {args} {
	set out ""
	foreach name $args {
		if {$name eq {}} continue
		append out " OBJECT            :$name\n"
	}
	return $out
}

proc structured_obj_list {args} {
	variable name2oid
	set out {}
	foreach {path name} $args {
		if {$name != {}} {set oid $name2oid($name)} {set oid {}}
		lappend out "$path=$oid"
	}
	return $out
}

proc param_hash {alg} {
    switch -glob $alg {
        gost2012_256:* {return hash_12_256}
        gost2012_512:* {return hash_12_512}
        * {return param_hash_94}
    }
}


proc param_encr {short_name} {
	variable name2oid
	if {[regexp {^\d+(\.\d+)+$} $short_name]} {
	return "$short_name"
	}
	switch -exact $short_name {
		cc_cipher_param {return param_encr_cc}
		{} {return param_encr_tc}
		cp_cipher_param_a {return param_encr_cpa}
		cp_cipher_param_b {return param_encr_cpb}
		cp_cipher_param_c {return param_encr_cpc}
		cp_cipher_param_d {return param_encr_cpd}
	}
}

proc encr_long_name {short_name} {
	variable name2oid
	switch -exact $short_name {
		"1.2.643.2.2.31.1" {return "id-Gost28147-89-CryptoPro-A-ParamSet"}
		"1.2.643.2.2.31.2" {return "id-Gost28147-89-CryptoPro-B-ParamSet"}
		"1.2.643.2.2.31.3" {return "id-Gost28147-89-CryptoPro-C-ParamSet"}
		"1.2.643.2.2.31.4" {return "id-Gost28147-89-CryptoPro-D-ParamSet"}
		"1.2.643.7.1.2.5.1.1" {return "GOST 28147-89 TC26 parameter set"}
		{} {return "GOST 28147-89 TC26 parameter set"}
	}
}



#
# Функции для управления клиентом и сервером при тестировании
# SSL-соединения
#

#  Параметры
#    Список аргументов командной строки клиента
#    список аргументов командной строки сервера
#    строка, которую надо передать на stdin клиенту
#
# Запускает openssl s_server и пытается приконнектиться к нему openssl
# s_client-ом. Возвращает список stdout  клиента, stderr клиента, кода
# завершения клиента, stdout
# сервера stderr сервера и кода завершения сервера.
# 
# Если процесс убит сигналом, возвращает в качестве кода завершения имя
# сигнала, иначе - числовое значение кода завершения ОС
# 
proc client_server {client_args server_args client_stdin} {
	log "CLIENT ARGS\n$client_args\n"
	log "SERVER ARGS\n$server_args\n"
	flush [test_log]
	set server [open_server $server_args]
	set client [open_client $client_args $client_stdin]
	log "server = $server client = $client"
	log "Both client and server started"
	flush [test_log]
	global finished
	log "Waitng for client to termintate"
	flush [test_log]
#	if {$::tcl_platform(platform) == "windows"} {
#		exec ../kbstrike [pid $client] 0x20
#	}
	vwait finished($client) 
	catch {stop_server $server}
	set list [concat [stop $client] [stop $server]]
	foreach channel {"CLIENT STDOUT" "CLIENT STDERR" "CLIENT EXIT CODE"  "SERVER STDOUT"
	"SERVER STDERR" "SERVER EXIT CODE"} data $list {
		log "$channel\n$data\n"
	}
	return $list
}
#
# Устанавливает командную строку для вызова клиента,
# в системный openssl на указанном хосте
#
proc remote_client {host} {
	if {[info hostname] == "$host"} {
		set ::test::client_unset {OPENSSL_CONF}
		set ::test::client_app "openssl s_client"
	} else {
		set ::test::client_unset {LD_LIBRARY_PATH OPENSSL_CONF}
		set ::test::client_app "ssh build@$host openssl s_client"
	}
}	
#
# Устанавливает командную строку для вызова клиента в указанную команду
# Необязательный параметр указывает список переменных окружения, которые
# НЕ НАДО передавать в эту команду
#
proc custom_client {command {forbidden_vars {}}} {
	set ::test::client_app $command
	set ::test::client_unset $forbidden_vars

}
#
# Восстанавливает станадртую клиентскую команду
#
proc our_client {} {
	catch {unset ::test::client_app}
	catch {unset ::test::client_unset}
}	

#
# Закрывает файл, указанный в соответствующем file_id, возвращает
# элемент глобального массива output, содержимое error message от close
# и код завершения процесса (имя сигнала)
proc stop {file_id} {
	global output
	fconfigure $file_id -blocking yes
	if {[catch {close $file_id} msg]} {
		if {[string match CHILD* [lindex $::errorCode 0]]} {
			set status [lindex $::errorCode 2]
		} else {
			set status 0
		}	
	}  else {
		set status 0
	}	
	return [list $output($file_id) $msg $status]
}	
#
# Завершает работу сервера
#
proc stop_server {file_id} {
#	puts $file_id "Q\n" 
#	catch {set xx [socket localhost 4433]}
	log "Interrupting process [pid $file_id]"
	flush [test_log]
	kill INT [pid $file_id]
	#puts -nonewline stderr "Waiting for server termination.."
	vwait finished($file_id)
	if [info exists xx] {close $xx}
#	puts stderr "Ok"
}	

#
# Запускает процесс с указанной командной строкой. Возвращает дескриптор
# файла в nonblocking mode с повешенным туда fileevent
# Очищает соответствующие элементы массивов output и finished
proc start_process {cmd_line read_event {mode "r"}} {
	set f [open "|$cmd_line" $mode]
	global output finished
	catch {unset finished($f)}
	fconfigure $f -buffering none -blocking n
	set output($f) ""
	fileevent $f readable [list $read_event $f]
	return $f
}	
#
# Обработчик fileevent-ов на чтение. Записывает считанные данные в
# элемент массива output соответствущий файлхендлу. В случае если
# достигнут eof, выставляет элемент массива finished. (элемент output
# при этом тоже трогается, чтобы vwait завершился)
#
proc process_read {f} {
	global output
	if {[eof $f]} {
		global finished
		fconfigure $f -blocking y
		set finished($f) 1
		append output($f) ""
		return
	}	
	append output($f) [read $f]
}	

#
#  Запускает openssl s_server с указанными аргументами и дожидается пока
#  он скажет на stdout ACCEPT. Возвращает filehandle, открытый на
#  чтение/запись
#
proc open_server {server_args} {
	global OPENSSL_APP
	global ENGINE_PATH
	if {[info exists ::test::server_conf]} {
		global env
		set save_conf $env(OPENSSL_CONF)
		set env(OPENSSL_CONF) $::test::server_conf
	}
	if {[info exists ::test::server_app]} {
		set server $::test::server_app
	} else {
		set server [list $OPENSSL_APP s_server]
	}
	if {[info exists ::test::server_unset]} {
		save_env $::test::server_unset
	}	
	set server [start_process [concat $server $server_args] process_read "r+"]
	restore_env
	if {[info exists save_conf]} {
		set env(OPENSSL_CONF) $save_conf
	}	

	global output finished
	#puts -nonewline stderr  "Waiting for server startup..."
	while {![regexp "\nACCEPT\n" $output($server)]} {
		vwait output($server)
		if {[info exists finished($server)]} {
			#puts stderr "error"
			return -code error [lindex  [stop $server] 1]
		}	
	}		
	#puts stderr "Ok"
	after 100
	return $server
}
#
# Сохраняет указанные переменные среды для последующего восстановления
# restore_env
#
proc save_env {var_list} {
	catch {array unset ::test::save_env}
	foreach var $var_list {
		if {[info exist ::env($var)]} {
			set ::test::save_env($var) $::env($var)
			unset ::env($var)
		}	
	}

}
proc restore_env {} {
	if {[array exists ::test::save_env]} {
		array set ::env [array get ::test::save_env]
		array unset ::test::save_env
	}	
	
}
#
# Сохраняет указанные переменные среды для последующего восстановления
# restore_env2. В отличие от save_env, не делает unset сохраненной переменной.
#
proc save_env2 {var_list} {
	catch {array unset ::test::save_env2}
	foreach var $var_list {
		if {[info exist ::env($var)]} {
			set ::test::save_env2($var) $::env($var)
		}	
	}

}
#
# Восстанавливает переменные среды, ранее сохраненные функцией save_env2 
# В отличие от функции restore_env, требует списка переменных и 
# восстанавливает только переменные из данного списка. Второе отличие -
# если переменная из списка не была сохранена, делает ей unset.
#
proc restore_env2 {var_list} {
	foreach var $var_list {
		if {[info exist ::test::save_env2($var)]} {
			set ::env($var) $::test::save_env2($var)
		} else {
			catch {unset ::env($var)}
		}
	}
	array unset ::test::save_env2
}


#
# Запускает s_client с указанными аргументами, передавая на stdin
# указанную строку
#
proc open_client {client_args client_stdin} {
	global OPENSSL_APP
	if [info exists ::test::client_app] {
		set client $::test::client_app
	} else {
		set client [list $OPENSSL_APP s_client]
	}
	if {[info exists ::test::client_unset]} {
		save_env $::test::client_unset
	}	
	if {[info exists ::test::client_conf]}  {
		set save_env(OPENSSL_CONF) $::env(OPENSSL_CONF)
		set ::env(OPENSSL_CONF) $::test::client_conf
	}
	set client [start_process [concat $client $client_args [list << $client_stdin]] process_read]
	restore_env
	return $client
}	
#
# Зачитывает список хостов из ../../ssl-ciphers
#
proc get_hosts {file} {
	set ::test::suffix "-$file"
	if [file readable $file.ciphers] {
		set f [open $file.ciphers]
	} else {	
		set f [open ../../ssl-ciphers/$file.ciphers r]
	}
	while {[gets $f line]>=0} {
		if {[regexp {^\s*#} $line]} continue
		append data "$line\n"
	}
	close $f
	global hosts
	array set hosts $data
}	
#
# Регистрирует пользователся (возможно удаленном) тестовом CA, используя
# скрипт testca установленный в PATH на CAhost.
#

proc registerUserAtCA {userdir CAhost CAprefix CApath} {
		global OPENSSL_APP
		log "registerUserAtCA $userdir $CAhost $CAprefix $CApath"
		set f [open  $userdir/req.pem]
		set request [read $f]
		close $f
		set token [::http::geturl http://$CAhost/$CAprefix/$CApath\
		-query [::http::formatQuery request $request startdate [clock\
		format [expr [clock seconds]-3600] -format "%y%m%d%H%M%SZ" -gmt y]]]
		if {[::http::ncode $token]!=200} {
			return -code error "Error certifying request [::http::data $token]"
		}
		log "Got a certificate. Saving"
		saveCertFromPKCS7 $userdir/cert.pem [::http::data $token]
}
proc saveCertFromPKCS7 {file pkcs7} {
		global OPENSSL_APP
		log saveCertFromPCS7
		log "$OPENSSL_APP pkcs7 -print_certs $pkcs7"
		set f [open "|[list $OPENSSL_APP pkcs7 -print_certs << $pkcs7]" r]
		set out [open $file w]
		set mode 0
		while {[gets $f line]>=0} {
			if {$mode==1} {
				puts $out $line
				if {$line eq "-----END CERTIFICATE-----"} {
					set mode 2
				}
			} elseif {$mode==0 && $line eq "-----BEGIN CERTIFICATE-----"} {
				set mode 1
				puts $out $line
			}
		}	
		close $f
		close $out
		if {$mode !=2 } {
			return -code error "Cannot get certificate from PKCS7 output"
		}	
}
#
# Invokes scp and discards stderr output if exit code is 0
#
proc scp {args} {
	if {[info exists env(SCP)]} {
		set scp $env(SCP)
	} else {
		set scp scp
	}	
	if {[catch [concat exec $scp $args] msg]} {
		if {[string match CHIDLD* [lindex $::errorCode 0]]} {
			return -code error -errorcode $::errorCode  $msg
		}
	}
}	

proc getCAAlgParams {CAhost CAprefix alg} {
 	if {$alg == "ec" || $alg == "dsa"} {
		set token [::http::geturl http://$CAhost/$CAprefix/$alg?algparams=1]
		if {[::http::ncode $token]!=200} {
			return -code error "Error getting algorithm parameters [::http::data $token]"
		}
		set f [open ${alg}params.pem w]
		puts $f [::http::data $token]
		close $f
	}
}	
#
# Copies CA certificate from specified CA into ca_$alg.pem
# Returns name of the ca certificate or empty line if something goes
# wrong and error wasn't properly detected
#
proc getCAcert {CAhost CApath alg} {
	set token [::http::geturl http://$CAhost$CApath/$alg?getroot=1]
	if {[::http::ncode $token]!=200} {
		return -code error "Error getting root cert for $alg: [::http::data $token]"
	}
	saveCertFromPKCS7 ca_$alg.pem [::http::data $token]	
	return ca_$alg.pem
}
#
# Returns decoded version of first pem object in the given file
#
proc readpem {filename} {
	set f [open $filename]
	fconfigure $f -translation binary
	set data [read $f]
	close $f
	if {[regexp -- "-----BEGIN \[^\n\]+-----\r?\n(.*\n)-----END" $data => b64]} {
		set data [::base64::decode $b64]
	}  
	return $data

}
	
proc der_from_pem {pem} {
	if {[regexp -- {^-----BEGIN ([^\n]*)-----\r?\n(.*)\r?\n-----END \1-----} $pem => => base64]} {
		::base64::decode $base64
	} {
		error "Not a PEM:\n$pem"
	}
}

proc engine_name {} {
	global env
	if {[info exists env(ENGINE_NAME)]} {
		switch -exact $env(ENGINE_NAME) {
			"open" {return "open"}
			"gost" {return "open"}
			"cryptocom" {return "ccore"}
			"ccore" {return "ccore"}
			default {error "Unknown engine '$env(ENGINE_NAME)'"}
		}
	} else {
		return "ccore"
	}
}

proc openssl_remote {files host cmdlinex suffix} {
		set hostname [exec hostname]
		set workpath /tmp/$hostname/$suffix
		save_env {LD_LIBRARY_PATH OPENSSL_CONF ENGINE_DIR}
		exec ssh build@$host mkdir -p $workpath
		foreach file $files {
			exec scp -r $file build@$host:$workpath
		}
		exec scp ../opnssl.sh build@$host:$workpath
		exec ssh build@$host chmod +x $workpath/opnssl.sh
		set cmdline [string map "TESTPATH $workpath" $cmdlinex]
		log "hstname: $hostname OpenSSL cmdline: $host remote_openssl $cmdline"
		set f [open "| ssh build@$host $workpath/opnssl.sh $cmdline" r]
		set output [read $f]
		restore_env
		if {[catch {close $f} msg]} {
			append output "STDERR CONTENTS:\n$msg"
			log $output
			if {[lindex $::errorCode 0]!="NONE"} {
				return -code error -errorcode $::errorCode $output
			}
		}
		return $output
}

package provide ossltest 0.7
