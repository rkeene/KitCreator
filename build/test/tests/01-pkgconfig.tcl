#! /usr/bin/env tclsh

# Tcl 8.4 doesn't support this test
if {$tcl_version == "8.4"} {
	exit 0
}

if {[tcl::pkgconfig get 64bit] == 0} {
	exit 0
}

exit 1
