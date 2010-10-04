#! /usr/bin/env tclsh

set buildflags [split [lindex $argv 1] -]

if {$tcl_version == "8.6"} {
	if {[lsearch -exact $buildflags "unthreaded"] == -1} {
		set isthreaded 1
	} else {
		set isthreaded 0
	}
} else {
	if {[lsearch -exact $buildflags "threaded"] == -1} {
		set isthreaded 0
	} else {
		set isthreaded 1
	}
}

if {!$isthreaded} {
	exit 0
}

package require Thread

exit 0
