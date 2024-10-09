# 
# Получает в командной строке URL и (опционально) строку для поиска
# сертификата. Выполняет HTTP-запрос и возрвщает результат
# В строке для поиска сертификата можно использовать прямые слэши вместо
# обратных.

if {!$argc || $argc>2} {
	puts stderr "Usage $argv0 url \[cert-spec\]"
}	

set url [lindex $argv 0]
if {$argc==2} {
	set certspec [string map {/ \\} [lindex $argv 1]]
}	


puts Started

package require tcom
set hh [::tcom::ref createobject WinHttp.WinHttpRequest.5.1]
$hh Open GET $url 0
if {[info exists certspec]} {
	puts "Setting Client Certificate $certspec"
	$hh SetClientCertificate $certspec
}
$hh Send
puts [$hh ResponseText]
