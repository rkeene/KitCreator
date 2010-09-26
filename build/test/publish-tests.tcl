#! /usr/bin/env tclsh

package require Tcl 8.5

set WEBDIR "/web/rkeene/devel/kitcreator/kitbuild"
if {![file isdir "kits"]} {
	puts stderr "Could not find kits/ directory, aborting."

        exit 1
}

set noncriticaltests [list "05-locale"]

##########################################################################
## PROCEDURES ############################################################
##########################################################################
proc pretty_print_key {key} {
	set version [lindex $key 0]
	set os [lindex $key 1]
	set cpu [lindex $key 2]

	switch -glob -- $version {
		"cvs_HEAD" {
			set version "from CVS HEAD"
		}
		"cvs_*" {
			set tag [join [lrange [split $version _] 1 end] _]
			set version "from CVS tag $tag"
		}
		default {
			set version "version $version"
		}
	}

	return "Tcl $version for [string totitle $os] on $cpu"
}

proc pretty_print_buildinfo {buildinfo} {
	set desc [list]
	foreach tag [list min static notk statictk threaded zip] {
		if {[lsearch -exact $buildinfo $tag] != -1} {
			switch -- $tag {
				"min" {
					lappend desc "Minimally Built"
				}
				"static" {
					lappend desc "Statically Linked"
				}
				"notk" {
					lappend desc "Without Tk"
				}
				"statictk" {
					lappend desc "Tk linked to Kit"
				}
				"threaded" {
					lappend desc "Threaded"
				}
				"zip" {
					lappend desc "Kit Filesystem in Zip"
				}
			}
		}
	}

	if {[llength $desc] == 0} {
		return "Default Build"
	}

	return [join $desc {, }]
}

proc pretty_print_size {size} {
	foreach unit [list "" K M G T P] {
		if {$size < 1024} {
			return "$size [string trim ${unit}B]"
		}

		set size [expr {${size} / 1024}]
	}
}

##########################################################################
## MAIN BODY #############################################################
##########################################################################

file delete -force -- $WEBDIR
file mkdir $WEBDIR

set fd [open [file join $WEBDIR index.html] w]

file copy -force -- {*}[glob kits/*] $WEBDIR

set totaltests_count [llength [glob tests/*.tcl]]

foreach file [lsort -dictionary [glob -directory $WEBDIR *]] {
	if {[file isdirectory $file]} {
		continue
	}

	switch -glob -- $file {
		"*.log" - "*.ttml" - "*.html" - "*.desc" {
			continue
		}
	}

	# Derive what we can from the filename
	set shortfile [file tail $file]
	set buildfile "${shortfile}-build.log"
	set failedtests [glob -nocomplain -tails -directory $WEBDIR "${shortfile}-\[0-9\]\[0-9\]-*.log"]

	## Split the filename into parts and store each part
	set kitbuildinfo [split $shortfile -]
	set tclversion [lindex $kitbuildinfo 1]
	set kitbuildinfo [lsort -dictionary [lrange $kitbuildinfo 2 end]]

	## Determine Kit OS from random file names
	unset -nocomplain kitos kitcpu
	if {[lsearch -exact $kitbuildinfo "win32"] != -1} {
		set idx [lsearch -exact $kitbuildinfo "win32"]
		set kitbuildinfo [lreplace $kitbuildinfo $idx $idx]
		set kitos "windows"
		set kitcpu "i586"
	} elseif {[lsearch -exact $kitbuildinfo "arm"] != -1} {
		set idx [lsearch -exact $kitbuildinfo "arm"]
		set kitbuildinfo [lreplace $kitbuildinfo $idx $idx]
		set kitos "linux"
		set kitcpu "arm"
	} else {
		set idx [lsearch -exact $kitbuildinfo "normal"]
		if {$idx != -1} {
			set kitbuildinfo [lreplace $kitbuildinfo $idx $idx]
		}

		set kitos [string tolower $tcl_platform(os)]
		set kitcpu [string tolower $tcl_platform(machine)]
	}

	# Generate array to describe this kit
	unset -nocomplain kitinfo
	set kitinfo(version) $tclversion
	set kitinfo(file) $shortfile
	set kitinfo(buildfile) $buildfile
	set kitinfo(failedtests) $failedtests
	set kitinfo(buildflags) $kitbuildinfo
	set kitinfo(os) $kitos
	set kitinfo(cpu) $kitcpu

	# Store kit information with all kits
	set key [list $tclversion $kitos $kitcpu]
	lappend allkitinfo($key) [array get kitinfo]
}

puts $fd "<html>"
puts $fd "  <head>"
puts $fd "    <title>KitCreator Build Status</title>"
puts $fd "  </head>"
puts $fd "  <body>"
puts $fd "    <table cellpadding=\"2\" border=\"1\">"
foreach key [lsort -dictionary [array names allkitinfo]] {
	puts $fd "      <tr>"
	puts $fd "        <th><u>Tclkit for [pretty_print_key $key]</u></th>"
	puts $fd "        <th>Status</th>"
	puts $fd "        <th>Log</th>"
	puts $fd "        <th>Failed Tests</th>"
	puts $fd "      </tr>"
	foreach kitinfo_list $allkitinfo($key) {
		puts $fd "      <tr>"
		unset -nocomplain kitinfo
		array set kitinfo $kitinfo_list

		if {[llength $kitinfo(failedtests)] == 0} {
			set status "OK"
			set bgcolor "green"
		} else {
			set status "FAILED"
			set bgcolor "yellow"
		}

		set failedtestshtml [list]
		foreach test [lsort -dictionary $kitinfo(failedtests)] {
			set testname [file rootname $test]
			set testname [split $testname -]

			for {set idx 0} {$idx < [llength $testname]} {incr idx} {
				set val [lindex $testname $idx]
				if {[string match {[0-9][0-9]} $val]} {
					set testname [join [lrange $testname $idx end] -]

					break
				}
			}

			if {[lsearch -exact $noncriticaltests $testname] == -1} {
				set bgcolor "red"
			}

			lappend failedtestshtml "<small><a href=\"$test\">$testname</a></small>"
		}


		puts $fd "        <td><a href=\"$kitinfo(file)\">[pretty_print_buildinfo $kitinfo(buildflags)]</a></td>"
		puts $fd "        <td bgcolor=\"$bgcolor\">$status</td>"
		puts $fd "        <td><small><a href=\"$kitinfo(buildfile)\">([pretty_print_size [file size [file join $WEBDIR $kitinfo(buildfile)]]])</a></small></td>"
		puts $fd "        <td>[join $failedtestshtml {, }]</td>"
		puts $fd "      </tr>"
	}

}
puts $fd "    </table>"
puts $fd "  </body>"
puts $fd "</html>"

close $fd
