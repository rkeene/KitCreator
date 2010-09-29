proc tclInit {} {
	rename tclInit {}

	global auto_path tcl_library tcl_libPath
	global tcl_version tcl_rcFileName
  
	# Resolve symlinks
	set noe /.KITDLL_TCL

	set tcl_library [file join $noe lib tcl$tcl_version]
	set tcl_libPath [list $tcl_library [file join $noe lib]]

	# get rid of a build residue
	unset -nocomplain ::tclDefaultLibrary

	# the following code only gets executed once on startup
	if {[info exists tcl_rcFileName]} {
		set vfsHandler [list ::vfs::kitdll::vfshandler tcl]

		# mount the executable, i.e. make all runtime files available
		vfs::filesystem mount $noe $vfsHandler

		# alter path to find encodings
		if {[info tclversion] eq "8.4"} {
			catch {
				load {} pwb
				librarypath [info library]
			}
		} else {
			encoding dirs [list [file join [info library] encoding]] ;# TIP 258
		}

		# fix system encoding, if it wasn't properly set up (200207.004 bug)
		if {[encoding system] eq "identity"} {
			if {[info exists ::tclkit_system_encoding] && $::tclkit_system_encoding != ""} {
				catch {
					encoding system $::tclkit_system_encoding
				}
			}
			unset -nocomplain ::tclkit_system_encoding
		}

		# If we've still not been able to set the encoding, revert to Tclkit defaults
		if {[encoding system] eq "identity"} {
			catch {
				switch $::tcl_platform(platform) {
					windows		{ encoding system cp1252 }
					macintosh	{ encoding system macRoman }
				        default		{ encoding system iso8859-1 }
				}
			}
		}

		# now remount the executable with the correct encoding
		vfs::filesystem unmount [lindex [::vfs::filesystem info] 0]

		# Resolve symlinks
		set noe [file dirname [file normalize [file join $noe __dummy__]]]

		set tcl_library [file join $noe lib tcl$tcl_version]
		set tcl_libPath [list $tcl_library [file join $noe lib]]

		vfs::filesystem mount $noe $vfsHandler
	}
  
	# load config settings file if present
	namespace eval ::vfs { variable tclkit_version 1 }
	catch { uplevel #0 [list source [file join $noe config.tcl]] }

	uplevel #0 [list source [file join $tcl_library init.tcl]]
  
	# reset auto_path, so that init.tcl's search outside of tclkit is cancelled
	set auto_path $tcl_libPath

	# This loads everything needed for "clock scan" to work
	# "clock scan" is used within "vfs::zip", which may be
	# loaded before this is run causing the root VFS to break
	catch { clock scan }
}
