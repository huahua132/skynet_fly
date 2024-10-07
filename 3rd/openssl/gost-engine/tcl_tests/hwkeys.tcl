package require testlib

start_tests "Работа с аппаратными носителями"

if [info exists ::env(BASE_OPENSSL_CONF)] {
	set openssl_cnf [myfile openssl.cnf]
	set bf [open $::env(BASE_OPENSSL_CONF) r]
	set f [open $openssl_cnf w]
	set engines {}
	set in_engines 0
	while {[gets $bf line] >= 0} {
		puts $f $line
		if {[regexp {^\[engine_section\]} $line]} {
			puts $f "ce_filecnt_keys = cefk_section"
		}
	}
	close $bf
	if {$tcl_platform(platform) eq "windows"} {
		set lib_prefix	""
		set lib_suffix ".dll"
	} else {
		set lib_prefix "lib"
		set lib_suffix ".so"
	}	
	puts $f "\[cefk_section\]	
dynamic_path = \$ENV::TEST_ENGINE_DIR/${lib_prefix}ce_filecnt_keys$lib_suffix
engine_id = ce_filecnt_keys
default_algorithms = ALL
\[req\]
prompt=no
distinguished_name = req_dn
\[ req_dn \]
OU=OpenSSL Team
L=Moscow
CN=Dummy user
emailAddress=openssl@cryptocom.ru
O=Cryptocom
C=RU"
	close $f
	file copy  [file dirname $env(BASE_OPENSSL_CONF)]/cryptocom.lic [file dirname $openssl_cnf]/cryptocom.lic
	set ::env(OPENSSL_CONF) $openssl_cnf
	puts [logchannel] "OPENSSL_CONF=$::env(OPENSSL_CONF)"
	set ::env(TEST_ENGINE_DIR) [regsub {(/[^/]+)$} $::env(ENGINE_DIR) {/t\1}]
	puts [logchannel] "TEST_ENGINE_DIR=$::env(TEST_ENGINE_DIR)"
}

set cnt_pln_file [myfile cnt_pln]
set cnt_pln_dot_file [myfile cnt.pln.S]
set cnt_pln FILECNT=$cnt_pln_file
set cnt_enc_file [myfile cnt_enc]
set cnt_enc FILECNT=$cnt_enc_file
file copy -force ../cnt.pln $cnt_pln_file
file copy -force ../cnt.pln $cnt_pln_dot_file
file copy -force ../cnt.pln default_file_container
file copy -force ../cnt.enc $cnt_enc_file
set cntname "test keys"

file delete $cnt_enc_file.cmd $cnt_pln_file.cmd
eval [exec enums2tcl]

foreach K {S X} {
	set cert$K [myfile cert$K.pem]
	set pubk$K [myfile pubk$K.pem]
	upvar 0 cert$K cert pubk$K pubk

	test -title "$K: сертификат и его открытый ключ" -id cert$K {
		run openssl req -new -x509 -key $cnt_pln.$K -keyform ENGINE -engine cryptocom -out $cert
		run openssl x509 -pubkey -noout -in $cert
		file rename _stdout $pubk
	}

	test -title "$K: Подписываем файл закрытым ключом" -id sign$K -dep cert$K {
		run openssl dgst -md_gost94 -sign $cnt_pln.$K -keyform ENGINE -engine cryptocom -out $cert.sig $cert
	}

	test -title "$K: Проверяем подпись на закрытом ключе" -dep sign$K {
		run openssl dgst -md_gost94 -prverify $cnt_pln.$K -keyform ENGINE -engine cryptocom -signature $cert.sig $cert
	}

	test -title "$K: Проверяем подпись на открытом ключе" -dep sign$K {
		run openssl dgst -md_gost94 -verify $pubk -signature $cert.sig $cert
	}

	test -title "$K: Подписываем файл закрытым ключом, контейнер с именем" -id sign$K -dep cert$K {
		run openssl dgst -md_gost94 -sign $cnt_pln:$cntname.$K -keyform ENGINE -engine cryptocom -out $cert.sig $cert
	}

	test -title "$K: Подписываем файл запароленным закрытым ключом" -dep cert$K {
		run openssl dgst -md_gost94 -sign $cnt_enc.$K -keyform ENGINE -engine cryptocom -out $cert.sig -passin pass:abcdefghijklmnopqrstuvwxyz1234567890 $cert
		run openssl dgst -md_gost94 -verify $pubk -signature $cert.sig $cert
	}

}

test -title "Читаем по полной спецификации" {
	run hwkeys -load $cnt_pln:$cntname.S
}

test -title "Читаем без имени контейнера" {
	run hwkeys -load $cnt_pln.S
}

test -title "Читаем без имени носителя"  {
	run hwkeys -load FILECNT:$cntname.S
}

test -title "Читаем без имен контейнера и носителя" {
	run hwkeys -load FILECNT.S
}

test -title "Читаем с именем носителя, содержащим .S" {
	run hwkeys -load FILECNT=$cnt_pln_dot_file.S
}

end_tests

proc write_cmd_file {filename args} {
	set f [open filename w]
	fconfigure $f -encoding binary
	puts -nonewline $f [binary format c* $args]
	close $f
}

test -title "Читаем, нет носителя, нет коллбэка" {
	write_cmd_file $cnt_pln_file.cmd $cc_rc_no_contact
	run -fail -stderr {regex {cc_rds_read_key.*==cc_rc_no_contact.*load_key failed}} \
		hwkeys -no-cb -load $cnt_pln.S
}

test -title "Читаем, нет носителя, есть коллбэк, носитель дали"

test -title "Читаем, нет носителя, есть коллбэк, запрос отменили"

test -title "Читаем, есть носитель, нет контейнера"

test -title "Читаем, не тот контейнер, нет коллбэка"

test -title "Читаем, не тот контейнер, есть коллбэк, носитель поменяли, опять не тот, еще раз поменяли, теперь тот"

test -title "Читаем, не тот контейнер, есть коллбэк, запрос отменили"

test -title "Читаем, нет этого ключа (другой есть)"

test -title "Читаем, ошибка чтения, нет коллбэка"

test -title "Читаем, ошибка чтения, устранена"

test -title "Читаем, ошибка чтения, таймаут"

test -title "Читаем, ошибка чтения, отмена"

test -title "Читаем, не сошлась CRC ключа"

test -title "Читаем парольный, даем пароль"

test -title "Читаем парольный, даем пароль со второй попытки"

test -title "Читаем парольный, ошибка возврата пароля"

test -title "Читаем парольный, отмена"

test -title "Пишем в свежий контейнер"

test -title "Проверяем подписью, что это - тот же самый ключ"

test -title "Пишем в тот же контейнер второй ключ зашифрованным"

test -title "Проверяем подписью, что оно"

test -title "Пишем безымянный"

test -title "Пишем зашифрованный, пароли совпадают со второй попытки"

test -title "Пишем зашифрованный, ошибка получения пароля"

test -title "Пишем зашифрованный, отмена"

test -title "Ошибка записи, нет коллбэка"

test -title "Ошибка записи, вернули носитель"

test -title "Ошибка записи, таймаут"

test -title "Ошибка записи, отмена"

test -title "Нет носителя, нет коллбэка"

test -title "Нет носителя, дали"

test -title "Нет носителя, таймаут"

test -title "Нет носителя, отмена"

test -title "Не тот контейнер, нет перезаписи, нет коллбэка"

test -title "Не тот контейнер, нет перезаписи, сменили носитель"

test -title "Не тот контейнер, нет перезаписи, таймаут"

test -title "Не тот контейнер, нет перезаписи, отмена"

test -title "Не тот контейнер, есть перезапись"

test -title "Ключ есть, перезапись запрещена"

test -title "Ключ есть, перезапись разрешена"

test -title "Затираем"

test -title "Затираем, нет носителя, нет коллбэка"

test -title "Затираем, нет носителя, дали носитель"

test -title "Затираем, нет носителя, таймаут"

test -title "Затираем, нет носителя, отмена"

test -title "Затираем, не тот контейнер, нет коллбэка"

test -title "Затираем, не тот контейнер, сменили носитель"

test -title "Затираем, не тот контейнер, таймаут"

test -title "Затираем, не тот контейнер, отмена"

test -title "Затираем контейнер без имени, даем без имени"

test -title "Затираем контейнер без имени, даем с именем"
