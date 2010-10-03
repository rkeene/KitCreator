proc tclInit {} {
	rename tclInit {}

	global auto_path tcl_library tcl_libPath
	global tcl_version
  
	# Set path where to mount VFS
	set tcl_mountpoint "/.KITDLL_TCL"

	set tcl_library [file join $tcl_mountpoint lib tcl$tcl_version]
	set tcl_libPath [list $tcl_library [file join $tcl_mountpoint lib]]

	# get rid of a build residue
	unset -nocomplain ::tclDefaultLibrary

	# the following code only gets executed once on startup
	if {[info exists ::initVFS]} {
		set vfsHandler [list ::vfs::kitdll::vfshandler tcl]

		# alter path to find encodings
		if {[info tclversion] eq "8.4"} {
			load {} pwb
			librarypath [info library]
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
		set tcl_mountpoint [file dirname [file normalize [file join $tcl_mountpoint __dummy__]]]

		set tcl_library [file join $tcl_mountpoint lib tcl$tcl_version]
		set tcl_libPath [list $tcl_library [file join $tcl_mountpoint lib]]

		vfs::filesystem mount $tcl_mountpoint $vfsHandler

	}

	# load config settings file if present
	namespace eval ::vfs { variable tclkit_version 1 }
	catch { uplevel #0 [list source [file join $tcl_mountpoint config.tcl]] }

	uplevel #0 [list source [file join $tcl_library init.tcl]]
  
	# reset auto_path, so that init.tcl's search outside of tclkit is cancelled
	set auto_path $tcl_libPath

	# This loads everything needed for "clock scan" to work
	# "clock scan" is used within "vfs::zip", which may be
	# loaded before this is run causing the root VFS to break
	catch { clock scan }

	# Load these, the original Tclkit does so it should be safe.
	foreach vfsfile [list vfsUtils vfslib] {
		uplevel #0 [list source [file join $tcl_mountpoint lib vfs ${vfsfile}.tcl]]
	}

	# Set a maximum seek to avoid reading the entire DLL looking for a
	# zip header
	catch {
		package require vfs::zip
		set ::zip::max_header_seek 8192
	}

	# Now that the initialization is complete, mount the user VFS if needed
	## Mount the VFS from the Shared Object
	if {[info exists ::initVFS] && [info exists ::tclKitFilename]} {
		catch {
			vfs::zip::Mount $::tclKitFilename "/.KITDLL_USER"

			lappend auto_path [file normalize "/.KITDLL_USER/lib"]
		}
	}

	## Mount the VFS from executable
	if {[info exists ::initVFS]} {
		catch {
			vfs::zip::Mount [info nameofexecutable] "/.KITDLL_APP"

			lappend auto_path [file normalize "/.KITDLL_APP/lib"]
		}
	}

	# Clean up
	unset -nocomplain ::zip::max_header_seek

	# Clean up after the kitInit.c:preInitCmd
	unset -nocomplain ::initVFS ::tclKitFilename
}
