#! /usr/bin/env tclsh

# Parse arguments
set opt_compression 1
if {[llength $argv] < 2} {
	puts stderr "Usage: installvfs.tcl <kitfile> <vfsdir> \[<enable_compression>\]"

	exit 1
}

set kitfile [lindex $argv 0]
set vfsdir [lindex $argv 1]
if {[lindex $argv 2] != ""} {
	set opt_compression [lindex $argv 2]
}

# Determine what storage mechanism is being used
set fd [open Makefile.common r]
set data [read $fd]
close $fd

if {[string match "*KIT_STORAGE_ZIP*" $data]} {
	set tclKitStorage zip
}
if {[string match "*KIT_STORAGE_MK4*" $data]} {
	set tclKitStorage mk4
}
if {[string match "*KIT_STORAGE_CVFS*" $data]} {
	set tclKitStorage cvfs
}

# Define procedures
proc copy_file {srcfile destfile} {
	switch -glob -- $srcfile {
		"*.tcl" - "*.txt" {
			set ifd [open $srcfile r]
			set ofd [open $destfile w]

			set ret [fcopy $ifd $ofd]

			close $ofd
			close $ifd
		}
		default {
			file copy -- $srcfile $destfile
		}
	}
}

proc recursive_copy {srcdir destdir} {
	foreach file [glob -nocomplain -directory $srcdir *] {
		set filetail [file tail $file]
		set destfile [file join $destdir $filetail]

		if {[file isdirectory $file]} {
			file mkdir $destfile

			recursive_copy $file $destfile

			continue
		}

		if {[catch {
			copy_file $file $destfile
		} err]} {
			puts stderr "Failed to copy: $file: $err"
		}
	}
}

# Update the kit, based on what kind of kit this is
switch -- $tclKitStorage {
	"mk4" {
		if {[catch {
			# Try as if a pre-existing Tclkit, or a tclsh
			package require vfs::mk4
		}]} {
			# Try as if uninitialized Tclkit
			catch {
				load "" vfs
				load "" Mk4tcl

				source [file join $vfsdir lib/vfs/vfsUtils.tcl]
				source [file join $vfsdir lib/vfs/vfslib.tcl]
				source [file join $vfsdir lib/vfs/mk4vfs.tcl]
			}
		}
		set mk4vfs::compress $opt_compression

		set handle [vfs::mk4::Mount $kitfile /kit -nocommit]

		recursive_copy $vfsdir /kit

		vfs::unmount /kit
	}
	"zip" {
		set kitfd [open $kitfile a+]
		fconfigure $kitfd -translation binary

		cd $vfsdir
		set zipfd [open "|zip -r - [glob *] 2> /dev/null"]
		fconfigure $zipfd -translation binary

		fcopy $zipfd $kitfd

		close $kitfd
		if {[catch {
			close $zipfd
		} err]} {
			puts stderr "Error while updating executable: $err"

			exit 1
		}
	}
	"cvfs" {
		# No-op
	}
}
