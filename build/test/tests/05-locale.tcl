#! /usr/bin/env tclsh

# Tcl 8.4 doesn't support fetching the system encoding from the environment
if {$tcl_version == "8.4"} {
	exit 0
}

if {[encoding system] == "utf-8"} {
	exit 0
}

puts "Locale:   [encoding system]"
puts "Expected: utf-8"

exit 1
