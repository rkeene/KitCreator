#! /usr/bin/env tclsh

lappend auto_path [file join installed-pkgs lib]
package require vfs::mk4

if {[llength $argv] != 2} {
	puts stderr "Usage: installvfs.tcl <kitfile> <vfsdir>"

	exit 1
}

proc copy_file {srcfile destfile} {
	switch -glob -- $srcfile {
		"*.tcl" {
			set ifd [open $srcfile r]
			set ofd [open $destfile w]

			fcopy $ifd $ofd

			close $ofd
			close $ifd
		}
		default {
			file copy -- $srcfile $destfile
		}
	}

	puts "Copied $srcfile to $destfile"
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

set kitfile [lindex $argv 0]
set vfsdir [lindex $argv 1]

set handle [vfs::mk4::Mount $kitfile /kit]

recursive_copy $vfsdir /kit

vfs::mk4::Unmount $handle /kit
