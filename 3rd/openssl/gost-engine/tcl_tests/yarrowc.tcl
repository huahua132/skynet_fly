set argport 7670
if {[lindex $argv 0] eq "-port"} {
	set argport [lindex $argv 1]
	set argv [lrange $argv 2 end]
}
set request [lindex $argv 0]
set len [switch $request ping {expr -1} protocol {expr -2} version {expr -3} check {expr 1} default {expr $request}]
set read_data {}

proc get_port {} {
	if {[regexp {^\d+$} $::argport]} {return $::argport}
	set f [open $::argport r]
	set r [read -nonewline $f]
	close $f
	return $r
}

proc get_data {socket} {
	set read_data [read $socket]
	if {$read_data eq ""} {
		close $socket
		handle_data
	} else {
		append ::read_data $read_data
	}
}

proc handle_data {} {
	global len read_data
	if {$len > 0} {
		if {$::request eq "check" && $read_data ne ""} {exit 0}
		if {$read_data eq ""} {
			puts stderr "not ready"
			exit 1
		}
		binary scan $read_data H* data
		set data [regsub -all ".{48}" [regsub -all ".." $data "& "] "&\n"]
		if {[string index $data end] eq "\n"} {set data [string replace $data end end]}
		puts $data
	} else {
		if {$len == -1 || $len == -3} {
			if {[string length $read_data] < 4} {error "Not enough data"}
			binary scan $read_data I rlen
			set read_data [string range $read_data 4 end]
			puts [encoding convertfrom utf-8 $read_data]
			if {[string length $read_data] != $rlen} {
				puts stderr "Real string length [string length $read_data] != claimed $rlen!"
				exit 2
			}
		} elseif {$len == -2} {
			if {[string length $read_data] < 4} {error "Not enough data"}
			if {[string length $read_data] > 4} {error "Excess data"}
			binary scan $read_data I r
			puts $r
		}
	}
	exit 0
}

set port [get_port]
		
if {[info exists errmsg] && $errmsg ne ""} {error $errmsg}
if {$port eq ""} {error "Cannot find port number"}

set s [socket localhost $port]
fconfigure $s -encoding binary -buffering none -blocking 0
fileevent $s readable [list get_data $s]
puts -nonewline $s [binary format I $len]
after 4000 {puts stderr "Timeout.  Read for now: '$read_data'"; exit 2}
vwait forever
