#!/usr/bin/tclsh
lappend auto_path .
package require ossltest

proc getConfigLine {var {section ""}} {
   global config
   if {[string length $section]} {
   		if {[regexp -indices "\n\\s*\\\[\\s*$section\\s*\\\]\\s*\n" $config start]} {
			set start [lindex $start 1]
		} else {
			return -code error "Section $section is not found"
		}	
	} else {
		set start 0
	}
	if {[regexp -indices "\n\\s*\\\[\[^\n\]+\\\]\\s*\n" [string range $config $start end] end]} {
		set end [expr $start+[lindex $end 0]]
	} else {
		set end end
	}
	if {![regexp "\n\\s*$var\\s*=\\s*(\\S\[^\n\]+?)\\s*\n" "\n[string range $config $start $end]" => value]} {
		return -code error "No variable $var in section $section"
	}	
	return $value
}

set config [getConfig] 

set openssl_def [getConfigLine openssl_conf]

set engine_section [getConfigLine {[^#]+}  [getConfigLine engines $openssl_def ]]

puts [getConfigLine engine_id $engine_section]




