#! /usr/bin/env tcl

package require vfs
#package require kitdll

namespace eval ::vfs::kitdll {}

# Convience functions
proc ::vfs::kitdll::Mount {hashkey local} {
	vfs::filesystem mount $local [list ::vfs::kitdll::vfshandler $hashkey]
	vfs::RegisterMount $local [list ::vfs::kitdll::Unmount]
}

proc ::vfs::kitdll::Unmount {local} {
	vfs::filesystem unmount $local
}

# Implementation

## Filesystem Data
namespace eval ::vfs::kitdll::data {}
set ::vfs::kitdll::data(joe) "Test\n"
set {::vfs::kitdll::metadata()} [list type directory ino 0 mode 0555 nlink 2 uid 0 gid 0 size 0 atime 0 mtime 0 ctime 0]
set ::vfs::kitdll::metadata(joe) [list type file ino 1 mode 0444 nlink 1 uid 0 gid 0 size 5 atime 0 mtime 0 ctime 0]
set ::vfs::kitdll::metadata(sub) [list type directory ino 2 mode 0555 nlink 1 uid 0 gid 0 size 0 atime 0 mtime 0 ctime 0]
set ::vfs::kitdll::metadata(sub/sub2) [list type directory ino 3 mode 0555 nlink 1 uid 0 gid 0 size 0 atime 0 mtime 0 ctime 0]

proc ::vfs::kitdll::data::getData {hashkey file {start 0} {end "end"}} {
	if {![info exists ::vfs::kitdll::data($file)]} {
		return -code error "Invalid operation"
	}

	return [string range $::vfs::kitdll::data($file) $start $end]
}

proc ::vfs::kitdll::data::getMetadata {hashkey file} {
	if {![info exists ::vfs::kitdll::metadata($file)]} {
		return -code error "No such file"
	}

	return $::vfs::kitdll::metadata($file)
}

proc ::vfs::kitdll::data::getChildren {hashkey directory} {
	set pattern [file join $directory {[^/]*}]

	set children [array names ::vfs::kitdll::metadata -regexp "^${pattern}\$"]

	set newchildren [list]
	foreach child $children {
		if {$child == ""} {
			continue
		}

		set tail [lindex [split $child /] end]

		lappend newchildren $tail
	}

	return $newchildren
}

## VFS and Chan I/O
### Dispatchers
proc ::vfs::kitdll::vfshandler {hashkey subcmd args} {
	set cmd $args
	set cmd [linsert $cmd 0 "::vfs::kitdll::vfsop_${subcmd}" $hashkey]

	return [eval $cmd]
}

proc ::vfs::kitdll::chanhandler {hashkey subcmd args} {
	set cmd $args
	set cmd [linsert $cmd 0 "::vfs::kitdll::chanop_${subcmd}" $hashkey]

	return [eval $cmd]
}

### Actual handlers
#### Channel operation handlers
proc ::vfs::kitdll::chanop_initialize {hashkey chanId mode} {
	return [list initialize finalize watch read seek]
}

proc ::vfs::kitdll::chanop_finalize {hashkey chanId} {
	unset -nocomplain ::vfs::kitdll::chandata([list $hashkey $chanId])

	return
}

proc ::vfs::kitdll::chanop_watch {hashkey chanId eventSpec} {
	array set chaninfo $::vfs::kitdll::chandata([list $hashkey $chanId])

	set chaninfo(watching) $eventSpec

	set ::vfs::kitdll::chandata([list $hashkey $chanId]) [array get chaninfo]

	if {[lsearch -exact $chaninfo(watching) "read"] != -1} {
		after 0 [list catch "chan postevent $chanId [list {read}]"]
	}

	return
}

proc ::vfs::kitdll::chanop_read {hashkey chanId bytes} {
	array set chaninfo $::vfs::kitdll::chandata([list $hashkey $chanId])

	set pos $chaninfo(pos)
	set len $chaninfo(len)

	if {[lsearch -exact $chaninfo(watching) "read"] != -1} {
		after 0 [list catch "chan postevent $chanId [list {read}]"]
	}

	if {$pos == $len} {
		return ""
	}

	set end [expr {$pos + $bytes}]
	if {$end > $len} {
		set end $len
	}

	set data [::vfs::kitdll::data::getData $hashkey $chaninfo(file) $pos $end]

	set dataLen [string length $data]
	incr pos $dataLen

	set chaninfo(pos) $pos

	set ::vfs::kitdll::chandata([list $hashkey $chanId]) [array get chaninfo]

	return $data
}

proc ::vfs::kitdll::chanop_seek {hashkey chanId offset origin} {
	array set chaninfo $::vfs::kitdll::chandata([list $hashkey $chanId])

	set pos $chaninfo(pos)
	set len $chaninfo(len)

	switch -- $origin {
		"start" - "0" {
			set pos $offset
		}
		"current" - "1" {
			set pos [expr {$pos + $offset}]
		}
		"end" - "2" {
			set pos [expr {$len + $offset}]
		}
	}

	if {$pos < 0} {
		set pos 0
	}

	if {$pos > $len} {
		set pos $len
	}

	set chaninfo(pos) $pos
	set ::vfs::kitdll::chandata([list $hashkey $chanId]) [array get chaninfo]

	return $pos
}

#### VFS operation handlers
proc ::vfs::kitdll::vfsop_stat {hashkey root relative actualpath} {
	catch {
		set ret [::vfs::kitdll::data::getMetadata $hashkey $relative]
	}

	if {![info exists ret]} {
		vfs::filesystem posixerror $::vfs::posix(ENOENT)
	}

	return $ret
}

proc ::vfs::kitdll::vfsop_access {hashkey root relative actualpath mode} {
	set ret [::vfs::kitdll::data::getMetadata $hashkey $relative]

	if {$mode & 0x2} {
		vfs::filesystem posixerror $::vfs::posix(EROFS)
	}

	return 1
}

proc ::vfs::kitdll::vfsop_matchindirectory {hashkey root relative actualpath pattern types} {
	set ret [list]

	catch {
		array set metadata [::vfs::kitdll::data::getMetadata $hashkey $relative]
	}

	if {![info exists metadata]} {
		return [list]
	}

	if {$pattern == ""} {

		set children [list $relative]
	} else {
		set children [::vfs::kitdll::data::getChildren $hashkey $relative]
	}

	foreach child $children {
		if {![string match $pattern $child]} {
			continue
		}

		unset -nocomplain metadata
		catch {
			array set metadata [::vfs::kitdll::data::getMetadata $hashkey $child]
		}

		if {[string index $actualpath end] == "/"} {
			set child "${actualpath}${child}"
		} else {
			set child "${actualpath}/${child}"
		}
		if {[string index $child end] == "/"} {
			set child [string range $child 0 end-1]
		}

		if {![info exists metadata(type)]} {
			continue
		}

		set filetype 0
		switch -- $metadata(type) {
			"directory" {
				set filetype [expr {$filetype | 0x04}]
			}
			"file" {
				set filetype [expr {$filetype | 0x10}]
			}
			"link" {
				set filetype [expr {$filetype | 0x20}]
			}
			default {
				continue
			}
		}

		if {($filetype & $types) != $types} {
			continue
		}

		lappend ret $child
	}

	return $ret
}

proc ::vfs::kitdll::vfsop_fileattributes {hashkey root relative actualpath {index -1} {value ""}} {
	set attrs [list -owner -group -permissions]

	if {$value != ""} {
		vfs::filesystem posixerror $::vfs::posix(EROFS)
	}

	if {$index == -1} {
		return $attrs
	}

	array set metadata [::vfs::kitdll::data::getMetadata $hashkey $relative]

	set attr [lindex $attrs $index]

	switch -- $attr {
		"-owner" {
			return $metadata(uid)
		}
		"-group" {
			return $metadata(gid)
		}
		"-permissions" {
			if {$metadata(type) == "directory"} {
				set metadata(mode) [expr {$metadata(mode) | 040000}]
			}

			return [format {0%o} $metadata(mode)]
		}
	}

	return -code error "Invalid index"
}

proc ::vfs::kitdll::vfsop_open {hashkey root relative actualpath mode permissions} {
	if {$mode != "" && $mode != "r"} {
		vfs::filesystem posixerror $::vfs::posix(EROFS)
	}

	catch {
		array set metadata [::vfs::kitdll::data::getMetadata $hashkey $relative]
	}

	if {![info exists metadata]} {
		vfs::filesystem posixerror $::vfs::posix(ENOENT)
	}

	if {$metadata(type) == "directory"} {
		vfs::filesystem posixerror $::vfs::posix(EISDIR)
	}

	if {[info command chan] != ""} {
		set chan [chan create [list "read"] [list ::vfs::kitdll::chanhandler $hashkey]]

		set ::vfs::kitdll::chandata([list $hashkey $chan]) [list file $relative pos 0 len $metadata(size) watching ""]

		return [list $chan]
	}

	if {[info command rechan] == ""} {
		catch {
			package require rechan
		}
	}

	if {[info command rechan] != ""} {
		set chan [rechan [list ::vfs::kitdll::chanhandler $hashkey] 2]

		set ::vfs::kitdll::chandata([list $hashkey $chan]) [list file $relative pos 0 len $metadata(size) watching ""]

		return [list $chan]
	}

	return -code error "No way to generate a channel, need either Tcl 8.5+, \"rechan\""
}

##### No-Ops since we are a readonly filesystem
proc ::vfs::kitdll::vfsop_createdirectory {args} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}
proc ::vfs::kitdll::vfsop_deletefile {args} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}
proc ::vfs::kitdll::vfsop_removedirectory {args} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}
proc ::vfs::kitdll::vfsop_utime {} {
	vfs::filesystem posixerror $::vfs::posix(EROFS)
}

package provide vfs::kitdll 1.0
