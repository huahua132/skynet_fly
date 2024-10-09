proc oid {oid name types} {
	global new_name2oid
	set new_name2oid($name) $oid
}

source [lindex $argv 0]
source name2oid.tcl

set differ 0
foreach name [array names name2oid] {
	if {![info exists new_name2oid($name)] || $new_name2oid($name) != $name2oid($name)} {set differ 1}
}
if {!$differ} {
	foreach name [array names new_name2oid] {
		if {![info exists name2oid($name)]} {set differ 1}
	}
}

if {$differ} {
	set n2of [open name2oid.tcl w]
	puts $n2of "array set name2oid {"
	foreach name [lsort [array names new_name2oid]] {
		puts $n2of "$name $new_name2oid($name)"
	}
	puts $n2of "}"
	close $n2of
}

