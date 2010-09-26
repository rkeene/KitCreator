#! /usr/bin/env tclsh

set outputname [lindex $argv 0]

if {[info nameofexecutable] == $outputname} {
	exit 0
}

exit 1
