#! /usr/bin/env tclsh

set outdir "/web/customers/kitcreator.rkeene.org/kits"
set info [list]
if {[info exists ::env(PATH_INFO)]} {
	set info [lmap item [split $::env(PATH_INFO) /] {
		if {$item eq ""} {
			continue
		}
		return -level 0 $item
	}]
}
set key [lindex $info end]
set resultFormat "html"
if {[llength $info] > 1} {
	set resultFormat [lindex $info 0]
}

set scheme http
if {[info exists ::env(HTTPS)]} {
	set scheme https
}
set base_url "${scheme}://kitcreator.rkeene.org/kits/$key"

set status "Unknown"
set terminal 0
if {![regexp {^[0-9a-f]+$} $key]} {
	set status "Invalid Key"
	set terminal 1

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

if {[info exists buildinfo]} {
	set description "Tcl $buildinfo(tcl_version)"
	append description ", KitCreator $buildinfo(kitcreator_version)"
	append description ", Platform $buildinfo(platform)"

	foreach {option value} $buildinfo(options) {
		switch -- $option {
			"kitdll" {
				if {$value} {
					append description ", Built as a Library"
				}
			}
			"dynamictk" {
				if {$value} {
					if {[lsearch -exact $buildinfo(packages) "tk"] != -1} {
						append description ", Forced Tk Dynamic Linking"
					}
				}
			}
			"threaded" {
				if {$value} {
					append description ", Threaded"
				} else {
					append description ", Unthreaded"
				}
			}
			"debug" {
				if {$value} {
					append description ", With Symbols"
				}
			}
			"minbuild" {
				if {$value} {
					append description ", Without Tcl pkgs/ and all encodings"
				}
			}
			"staticlibssl" {
				if {$value} {
					append description ", Statically linked to LibSSL"
				}
			}
			"staticpkgs" {
				if {$value} {
					append description ", With Tcl 8.6+ pkgs/ directory all packages statically linked in"
				}
			}
			"storage" {
				switch -- $value {
					"mk4" {
						append description ", Metakit-based"
					}
					"zip" {
						append description ", Zip-kit"
					}
					"cvfs" {
						append description ", Static Storage"
					}
				}
			}
		}
	}

	if {[llength $buildinfo(packages)] > 0} {
		append description ", Packages: [join $buildinfo(packages) {, }]"
	} else {
		append description ", No packages"
	}
}

if {[info exists outfile]} {
	set build_log_url "${base_url}/${filename}.log"
	if {[file exists $outfile]} {
		set status "Complete"
		set terminal 1

		set url "${base_url}/$filename"
	} elseif {[file exists "${outfile}.buildfail"]} {
		set status "Failed"
		set terminal 1
	} else {
		set status "Building"
	}
}

if {$resultFormat in {json dict}} {
	set terminalBoolean [lindex {false true} $terminal]

	set resultsDict [dict create \
		status [string tolower $status] \
		terminal $terminalBoolean \
	]
	if {[string tolower $status] eq "complete"} {
		dict set resultsDict kit_url $url
	}
	if {[string tolower $status] in {complete building failed}} {
		dict set resultsDict build_log_url $build_log_url
		catch {
			dict set resultsDict tcl_version $buildinfo(tcl_version)
		}
		catch {
			dict set resultsDict kitcreator_version $buildinfo(kitcreator_version)
		}
		catch {
			dict set resultsDict platform $buildinfo(platform)
		}
	}
}

switch -exact -- $resultFormat {
	"html" {
		# Handled below
	}
	"json" {
		puts "Content-Type: application/json"
		puts ""
		set resultsJSONItems [list]
		foreach {key value} $resultsDict {
			switch -exact -- $key {
				"terminal" {
				}
				default {
					set value "\"$value\""
				}
			}
			lappend resultsJSONItems "\"$key\": $value"
		}
		set resultsJSON "{[join $resultsJSONItems {, }]}"
		puts $resultsJSON
		exit 0
	}
	"dict" {
		puts "Content-Type: text/plain"
		puts ""
		puts $resultsDict
		exit 0
	}
	default {
		exit 1
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
puts "\t\t<p><b>Status:</b> $status"
if {[info exists url]} {
	puts "\t\t<p><b>URL:</b> <a href=\"$url\">$url</a>"
}
if {[info exists description]} {
	puts "\t\t<p><b>Description:</b> $description"
}
if {[info exists logfile]} {
	catch {
		set fd [open $logfile]
		set logdata [read $fd]
		close $fd


		puts "\t\t<p><b>Log:</b><pre>\n$logdata</pre>"
	}
}
puts "\t</body>"
puts "</html>"
