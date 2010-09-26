#! /usr/bin/env tclsh

set outputname [lindex $argv 0]

if {[info nameofexecutable] == $outputname} {
	exit 0
}

# Under Wine, the drive letter is added
if {[info nameofexecutable] == "Z:$outputname"} {
	exit 0
}

puts "Info NameOfExe: [info nameofexecutable]"
puts "Expected:       $outputname"

exit 1
