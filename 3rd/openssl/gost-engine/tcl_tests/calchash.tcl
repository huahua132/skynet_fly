#!/usr/bin/tclsh
lappend auto_path [file dirname [info script]]
package require test

if {$::tcl_platform(platform) eq "windows"} {
	set prefix {//laputa/dist/magpro/FSB_CryptoPack_21.1/binaries}
} else {
	set prefix {/net/laputa/pub/magpro/FSB_CryptoPack_21.1/binaries}
}
set PREFIX_ENV_NAME CALCHASH_PREFIX
if {$argc != 1} {
        puts stderr "Usage $argv0 path"
	puts stderr "This script tests programms prefix/path/calchach and prefix/path/gostsum."
	puts stderr "Defauld prefix is $prefix"
	puts stderr "Prefix can be changes by envirament veriable $PREFIX_ENV_NAME"
        exit 1
}

if {[info exist env($PREFIX_ENV_NAME)]} {
	set prefix $env($PREFIX_ENV_NAME)
}
set path [lindex $argv 0]

set testdir [exec hostname]-hashes
puts $testdir
catch {file delete -force $testdir}
file mkdir $testdir
cd $testdir

start_tests "Тесты для программ calchash и gostsum"

test -createsfiles dgst.dat "calchash" {
	makeFile dgst.dat [string repeat "Test data to digest.\n" 100] binary
	string match *DB9232D96CAE7AABA817350EF6CF4C25604D8FD36965F78CEB3CE59FD31CCB2A [exec $prefix/$path/calchash dgst.dat]
} 0 1 

test -platform unix "gostsum (paramset cryptopro-A)" {
	exec $prefix/$path/gostsum dgst.dat
} 0 "5c8621c036f8636fa3ea711a78e5051f607c87b4b715482af74b2b1cce62e442 dgst.dat" 


test -platform unix "gostsum -t (paramset test)" {
	exec $prefix/$path/gostsum -t dgst.dat
} 0 "db9232d96cae7aaba817350ef6cf4c25604d8fd36965f78ceb3ce59fd31ccb2a dgst.dat" 


end_tests
