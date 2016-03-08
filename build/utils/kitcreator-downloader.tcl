#!/usr/bin/env tclsh
# KitCreator downloader v0.2.0 -- download Tclkits created with the KitCreator
# Web Interface. Works with Tcl 8.5+ and Jim Tcl v0.75+.
# Copyright (C) 2016, dbohdan.
# License: MIT.
proc download url {
    # Guess at what the buildinfo URL might be if we are given, e.g., a building
    # page URL.
    set url [string map {/building {}} $url]
    if {![string match */buildinfo $url]} {
        append url /buildinfo
    }

    set buildInfo [exec curl -s $url]

    set filename [dict get $buildInfo filename]
    append filename -[dict get $buildInfo tcl_version]
    append filename -[dict get $buildInfo platform]

    foreach option {staticpkgs threaded debug} {
        if {[dict exists $buildInfo options $option] &&
                [dict get $buildInfo options $option]} {
            append filename -$option
        }
    }

    append filename -[join [dict get $buildInfo packages] -]

    set tail [file tail $url]
    # We can't use [file dirname] here because it will transform
    # "http://example.com" into "http:/example.com".
    set baseUrl [string range $url 0 end-[string length $tail]]
    if {[string index $baseUrl end] ne {/}} {
        append baseUrl /
    }
    set tclkit $baseUrl[dict get $buildInfo filename]

    puts "Downloading $tclkit to $filename..."
    exec curl -o $filename $tclkit >@ stdout 2>@ stderr
}

set url [lindex $argv 0]
if {$url eq {}} {
    puts "usage: $argv0 url"
    puts {The URL must be a KitCreator Web Interface buildinfo page.}
} else {
    download $url
}
