#! /usr/bin/env tclsh

namespace eval ::mk {}
namespace eval ::mk::file {}
namespace eval ::mk::view {}
namespace eval ::mk::cursor {}
namespace eval ::mk::row {}
namespace eval ::mk::private {}

proc ::mk::file {cmd args} {
	set args [lindex $args 0 ::mk::file::${cmd}]

	return [eval $args]
}

proc ::mk::file::open {args} {
	if {[llength $args] == 0} {
		# Return open tags

		set retval [list]
		foreach tag [array names ::mk::private::tags] {
			unset -nocomplain taginfo
			array set taginfo $::mk::private::tags($tag)

			lappend retval $tag $taginfo(file)
		}

		return 
	}

	set tag [lindex $args 0]
	if {[info exists ::mk::private::tags($tag)]} {
		return -code error "tag is already open"
	}

	set taginfo(writable) 1
	set taginfo(commit_on_close) 1
	set taginfo(commit_on_set) 0
	set taginfo(extend) 0
	set taginfo(shared) 0

	if {[llength $args] == 1} {
		# Use in-memory file

		set taginfo(file) ""
		set taginfo(fd) ""
	} else {
		set filename [lindex $args 1]

		foreach opt [lrange $args 2 end] {
			switch -- $opt {
				"-readonly" {
					set taginfo(writable) 0
				}
				"-nocommit" {
					set taginfo(commit_on_close) 0
				}
				"-extend" {
					set taginfo(extend) 1
				}
				"-shared" {
					set taginfo(shared) 1
				}
			}
		}

		if {$taginfo(writable)} {
			set fd [open $filename a+]
			seek $fd 0 start
		} else {
			set fd [open $filename r]
		}

		set taginfo(file) $filename
		set taginfo(fd) $fd
	}

	set ::mk::private::changes($tag) [list]
	set ::mk::private::tags($tag) [array get taginfo]
}

proc ::mk::file::close {tag} {
	if {![info exists ::mk::private::tags($tag)]} {
		return -code error "no storage with this name"
	}

	array set taginfo $::mk::private::tags($tag)

	if {$taginfo(commit_on_close) && $taginfo(writable) && $taginfo(fd) != ""} {
		mk::file commit $tag -full
	}

	if {$taginfo(fd) != ""} {
		close $taginfo(fd)
	}

	unset ::mk::private::changes($tag)
	unset ::mk::private::tags($tag)
}

proc ::mk::file::views {{tag ""}} {
	return -code error "Not Implemented"
}

proc ::mk::file::commit {tag {fullOpt ""}} {
	if {![info exists ::mk::private::tags($tag)]} {
		return -code error "no storage with this name"
	}

	array set taginfo $::mk::private::tags($tag)

	if {$fullOpt == "-full"} {
		# Flush asides
		# XXX: TODO
	}

	if {$taginfo(fd) == ""} {
		# We can't commit if we weren't asked to write to stable
		# storage
		return
	}

	# XXX: TODO
	return -code error "Not Implemented"
}

proc ::mk::file::rollback {tag {fullOpt ""}} {
	if {![info exists ::mk::private::tags($tag)]} {
		return -code error "no storage with this name"
	}

	if {$fullOpt == "-full"} {
		# Clear asides ...
		# XXX: TODO
	}

	set ::mk::private::changes($tag) ""
}

proc ::mk::file::load {{tag ""} {channel ""}} {
	return -code error "Not Implemented"
}

proc ::mk::file::save {{tag ""} {channel ""}} {
	return -code error "Not Implemented"
}

proc ::mk::file::aside {{tag1 ""} {tag2 ""}} {
	return -code error "Not Implemented"
}

proc ::mk::file::autocommit {tag} {
	if {![info exists ::mk::private::tags($tag)]} {
		return -code error "no storage with this name"
	}

	array set taginfo $::mk::private::tags($tag)

	set taginfo(commit_on_close) 1

	set ::mk::private::tags($tag) [array get taginfo]
}

proc ::mk::view {cmd args} {
	return -code error "Not Implemented"
}

proc ::mk::cursor {cmd args} {
	return -code error "Not Implemented"
}

proc ::mk::row {cmd args} {
	return -code error "Not Implemented"
}

proc ::mk::get {args} {
	return -code error "Not Implemented"
}

proc ::mk::set {args} {
	return -code error "Not Implemented"
}

proc ::mk::loop {args} {
	return -code error "Not Implemented"
}

proc ::mk::select {args} {
	return -code error "Not Implemented"
}

proc ::mk::channel {args} {
	return -code error "Not Implemented"
}

package provide Mk4tcl 2.4.9.6
