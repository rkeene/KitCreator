#! /usr/bin/env tclsh

if {[llength $argv] != 2} {
	puts stderr "Usage: installvfs.tcl <kitfile> <vfsdir>"

	exit 1
}

set kitfile [lindex $argv 0]
set vfsdir [lindex $argv 1]

if {[catch {
	package require vfs::mk4
}]} {
	catch {
		load "" vfs
		load "" Mk4tcl

		source [file join $vfsdir lib/vfs/vfsUtils.tcl]
		source [file join $vfsdir lib/vfs/vfslib.tcl]
		source [file join $vfsdir lib/vfs/mk4vfs.tcl]
	}
}

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

set handle [vfs::mk4::Mount $kitfile /kit -nocommit]

recursive_copy $vfsdir /kit

vfs::unmount /kit
