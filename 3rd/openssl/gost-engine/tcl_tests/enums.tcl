set f [open enums2tcl.c w]
puts $f "#include \"../ccore/ccapi.h\""
puts $f "#include \"../ccore/ccrdscb.h\""
puts $f "#include <stdio.h>"
puts $f "int main (void) {"
set inc [open ../ccore/ccapi.h r]
while {[gets $inc line] >= 0} {
	if [regexp {\bcc_rc_\w+} $line code] {
		puts $f "printf(\"set $code %d\\n\", $code);"
	}
}
close $inc
set inc [open ../ccore/ccrdscb.h r]
while {[gets $inc line] >= 0} {
	if [regexp {\bcc_rds_cb_(rc|op|stage)_\w+} $line code] {
		puts $f "printf(\"set $code %d\\n\", $code);"
	}
}
close $inc
puts $f "return 0;"
puts $f "}"
close $f

