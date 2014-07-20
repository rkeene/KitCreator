#! /usr/bin/env tclsh

set outdir "/web/customers/kitcreator.rkeene.org/kits"
set key ""
if {[info exists ::env(PATH_INFO)]} {
	set key [lindex [split $::env(PATH_INFO) "/"] 1]
}

set status "Unknown"
set terminal 0
if {![regexp {^[0-9a-f]+$} $key]} {
	set status "Invalid Key"

	unset key
}

if {[info exists key]} {
	set workdir [file join $outdir $key]
}

if {[info exists workdir]} {
	if {[file exists $workdir]} {
		set fd [open [file join $workdir buildinfo]]
		set buildinfo_list [gets $fd]
		close $fd
		array set buildinfo $buildinfo_list
		set filename $buildinfo(filename)

		set outfile [file join $workdir $filename]
		set logfile "${outfile}.log"
	} else {
		set status "Queued"
	}
}

if {[info exists outfile]} {
	if {[file exists $outfile]} {
		set status "Complete"
		set terminal 1

		set url "http://kitcreator.rkeene.org/kits/$key/$filename"
	} elseif {[file exists "${outfile}.buildfail"]} {
		set status "Failed"
		set terminal 1
	} else {
		set status "Building"
	}
}

puts "Content-Type: text/html"
if {[info exists url]} {
	# Use a refresh here instead of a "Location" so that
	# the client can see the page
	puts "Refresh: 0;url=$url"
} else {
	if {!$terminal} {
		puts "Refresh: 30;url=."
	}
}
puts ""
puts "<html>"
puts "\t<head>"
puts "\t\t<title>KitCreator, Web Interface</title>"
puts "\t</head>"
puts "\t<body>"
puts "\t\t<h1>KitCreator Web Interface</h1>"
puts "\t\t<p><b>Status:</b> $status</p>"
if {[info exists url]} {
	puts "\t\t<p><b>URL:</b> <a href=\"$url\">$url</a></p>"
}
if {[info exists logfile]} {
	catch {
		set fd [open $logfile]
		set logdata [read $fd]
		close $fd


		puts "\t\t<p><b>Log:</b><pre>\n$logdata</pre></p>"
	}
}
puts "\t</body>"
puts "</html>"
