#! /usr/bin/env tclsh

if {[llength $argv] != 2} {
	puts stderr "Usage: kitdll <hashkey> <startdir>"

	exit 1
}

set hashkey [lindex $argv 0]
set startdir [lindex $argv 1]

proc shorten_file {dir file} {
	set dirNameLen [string length $dir]

	if {[string range $file 0 [expr {$dirNameLen - 1}]] == $dir} {
		set file [string range $file $dirNameLen end]
	}

	if {[string index $file 0] == "/"} {
		set file [string range $file 1 end]
	}
	return $file
}

proc recursive_glob {dir} {
	set children [glob -nocomplain -directory $dir *]

	set ret [list $dir]
	foreach child $children {
		unset -nocomplain childinfo
		catch {
			file stat $child childinfo
		}

		if {![info exists childinfo(type)]} {
			continue
		}

		if {$childinfo(type) == "directory"} {
			foreach add [recursive_glob $child] {
				lappend ret $add
			}

			continue
		}

		if {$childinfo(type) != "file"} {
			continue
		}

		lappend ret $child
	}

	return $ret
}

# Convert a string into a C-style binary string
## XXX: This function needs to be optimized
proc stringify {data} {
	set ret "\""
	for {set idx 0} {$idx < [string length $data]} {incr idx} {
		binary scan [string index $data $idx] H* char

		append ret "\\x${char}"

		if {($idx % 20) == 0 && $idx != 0} {
			append ret "\"\n\""
		}
	}

	set ret [string trim $ret "\n\""]

	set ret "\"$ret\""

	return $ret
}

# This function must be kept in-sync with the generated C function below
proc kitdll_hash {path} {
	set h 0
	set g 0

	for {set idx 0} {$idx < [string length $path]} {incr idx} {
		binary scan [string index $path $idx] H* char
		set char "0x$char"

		set h [expr {($h << 4) + $char}]
		set g [expr {$h & 0xf0000000}]
		if {$g != 0} {
			set h [expr {($h & 0xffffffff) ^ ($g >> 24)}]
		}

		set h [expr {$h & ((~$g) & 0xffffffff)}]
	}

	return $h
}

# Generate list of files to include in output
set files [recursive_glob $startdir]

# Insert dummy entry cooresponding to C dummy entry
set files [linsert $files 0 "__DUMMY__"]

# Produce C89 compatible header
set cpp_tag "KITDLL_[string toupper $hashkey]"
set code_tag "kitdll_[string tolower $hashkey]"
set hashkey [string tolower $hashkey]

puts "#ifndef $cpp_tag"
puts "#  define $cpp_tag 1"
puts {
#  ifdef HAVE_STDC
#    ifndef HAVE_UNISTD_H
#      define HAVE_UNISTD_H 1
#    endif
#    ifndef HAVE_STRING_H
#      define HAVE_STRING_H 1
#    endif
#  endif
#  ifdef HAVE_UNISTD_H
#    include <unistd.h>
#  endif
#  ifdef HAVE_STRING_H
#    include <string.h>
#  endif

#  ifndef LOADED_KITDLL_COMMON
#    define LOADED_KITDLL_COMMON 1

typedef enum {
	KITDLL_FILETYPE_FILE,
	KITDLL_FILETYPE_DIR
} kitdll_filetype_t;

struct kitdll_data {
	const char *             name;
	unsigned long            index;
	unsigned long            size;
	kitdll_filetype_t        type;
	const unsigned char *    data;
};

static unsigned long kitdll_hash(const unsigned char *path) {
	unsigned long i, h = 0, g = 0;

	for (i = 0; path[i]; i++) {
		h = (h << 4) + path[i];
		g = h & 0xf0000000;
		if (g) {
			h ^= (g >> 24);
		}
		h &= ((~g) & 0xffffffffLU);
	}
        
        return(h);
}

#  endif /* !LOADED_KITDLL_COMMON */}
puts ""

puts "static struct kitdll_data ${code_tag}_data\[\] = {"
puts "\t{"
puts "\t\t.name  = NULL,"
puts "\t\t.index = 0,"
puts "\t\t.type  = 0,"
puts "\t\t.size  = 0,"
puts "\t\t.data  = NULL,"
puts "\t},"
for {set idx 1} {$idx < [llength $files]} {incr idx} {
	set file [lindex $files $idx]
	set shortfile [shorten_file $startdir $file]

	unset -nocomplain finfo type
	file stat $file finfo

	switch -- $finfo(type) {
		"file" {
			set type "KITDLL_FILETYPE_FILE"
			set size $finfo(size)

			set fd [open $file]
			fconfigure $fd -translation binary
			set data [read $fd]
			close $fd

			set data "(unsigned char *) [stringify $data]"
		}
		"directory" {
			set type "KITDLL_FILETYPE_DIR"
			set data "NULL"
			set size 0
		}
	}

	puts "\t{"
	puts "\t\t.name  = \"$shortfile\","
	puts "\t\t.index = $idx,"
	puts "\t\t.type  = $type,"
	puts "\t\t.size  = $size,"
	puts "\t\t.data  = $data,"
	puts "\t},"
}
puts "};"
puts ""

puts "static unsigned long ${code_tag}_lookup_index(const char *path) {"
puts "\tswitch (kitdll_hash((unsigned char *) path)) {"

for {set idx 1} {$idx < [llength $files]} {incr idx} {
	set file [lindex $files $idx]
	set shortfile [shorten_file $startdir $file]
	set hash [kitdll_hash $shortfile]

	lappend indexes_per_hash($hash) [list $shortfile $idx]
}

foreach {hash idx_list} [array get indexes_per_hash] {
	puts "\t\tcase $hash:"

	if {[llength $idx_list] == 1} {
		set idx [lindex $idx_list 0 1]

		puts "\t\t\treturn($idx);"
	} else {
		foreach idx_ent $idx_list {
			set shortfile [lindex $idx_ent 0]
			set idx [lindex $idx_ent 1]

			puts "\t\t\tif (strcmp(path, \"$shortfile\") == 0) return($idx);"
		}
		puts "\t\t\tbreak;"
	}
}

puts "\t}"
puts "\treturn(0);"
puts "}"
puts ""

puts "static struct kitdll_data *${code_tag}_getData(const char *path, unsigned long index) {"
puts "\tif (path != NULL) {"
puts "\t\tindex = ${code_tag}_lookup_index(path);"
puts "\t}"
puts ""
puts "\tif (index == 0) {"
puts "\t\treturn(NULL);"
puts "\t}"
puts ""
puts "\tif (path != NULL) {"
puts "\t\tif (strcmp(path, ${code_tag}_data\[index\].name) != 0) {"
puts "\t\t\treturn(NULL);"
puts "\t\t}"
puts "\t}"
puts ""
puts "\treturn(&${code_tag}_data\[index\]);"
puts "}"
puts ""

puts "static unsigned long ${code_tag}_getChildren(const char *path, unsigned long *outbuf, unsigned long outbuf_count) {"
puts "\tunsigned long index;"
puts "\tunsigned long num_children = 0;"
puts ""
puts "\tindex = ${code_tag}_lookup_index(path);"
puts "\tif (index == 0) {"
puts "\t\treturn(0);"
puts "\t}"
puts ""
puts "\tif (${code_tag}_data\[index\].type != KITDLL_FILETYPE_DIR) {"
puts "\t\treturn(0);"
puts "\t}"
puts ""
puts "\tif (strcmp(path, ${code_tag}_data\[index\].name) != 0) {"
puts "\t\treturn(0);"
puts "\t}"
puts ""
puts "\tswitch (index) {"

unset -nocomplain children
array set children [list]
for {set idx 1} {$idx < [llength $files]} {incr idx} {
	set file [lindex $files $idx]
	set shortfile [shorten_file $startdir $file]

	unset -nocomplain finfo type
	file stat $file finfo

	if {$finfo(type) != "directory"} {
		continue;
	}

	# Determine which children are under this directory
	## Convert the current pathname to a regular expression that matches exactly
	set file_regexp [string map [list "\\" "\\\\" "." "\\." "\{" "\\\{" "\}" "\\\}" "*" "\\*"] $file]

	## Search for pathnames which start with exactly our name, followed by a slash
	## followed by no more slashes (direct descendants)
	set child_idx_list [lsearch -regexp -all $files "^${file_regexp}/\[^/\]*$"]

	set children($idx) $child_idx_list

	puts "\t\tcase $idx:"
	puts "\t\t\tnum_children = [llength $child_idx_list];"
	puts "\t\t\tbreak;"
	
}

puts "\t}"
puts ""
puts "\tif (outbuf == NULL) {"
puts "\t\treturn(num_children);"
puts "\t}"
puts ""
puts "\tif (num_children > outbuf_count) {"
puts "\t\tnum_children = outbuf_count;"
puts "\t}"
puts ""
puts "\tif (num_children == 0) {"
puts "\t\treturn(num_children);"
puts "\t}"
puts ""
puts "\tif (outbuf_count > num_children) {"
puts "\t\toutbuf_count = num_children;"
puts "\t}"
puts ""
puts "\tswitch (index) {"

foreach {idx child_idx_list} [array get children] {
	if {[llength $child_idx_list] == 0} {
		continue
	}

	puts "\t\tcase $idx:"
	puts "\t\t\tswitch(outbuf_count) {"

	for {set child_idx_idx [expr {[llength $child_idx_list] - 1}]} {$child_idx_idx >= 0} {incr child_idx_idx -1} {
		set child_idx [lindex $child_idx_list $child_idx_idx]

		puts "\t\t\t\tcase [expr {$child_idx_idx + 1}]:"
		puts "\t\t\t\t\toutbuf\[$child_idx_idx\] = $child_idx;"
	}

	puts "\t\t\t}"

	puts "\t\t\tbreak;"
}

puts "\t}"
puts ""
puts "\treturn(num_children);"
puts "}"
puts ""

puts "#  ifdef KITDLL_MAKE_LOADABLE"

set fd [open "vfs_kitdll_data.c"]
puts [read $fd]
close $fd


puts "static cmd_getData_t *getCmdData(const char *hashkey) {"
puts "\treturn(${code_tag}_getData);"
puts "}"
puts ""
puts "static cmd_getChildren_t *getCmdChildren(const char *hashkey) {"
puts "\treturn(${code_tag}_getChildren);"
puts "}"
puts ""

puts "int Vfs_kitdll_data_${hashkey}_Init(Tcl_Interp *interp) {"
puts "\tTcl_Command tclCreatComm_ret;"
puts "\tint tclPkgProv_ret;"
puts ""
puts "\ttclCreatComm_ret = Tcl_CreateObjCommand(interp, \"::vfs::kitdll::data::${hashkey}::getMetadata\", getMetadata, NULL, NULL);"
puts "\tif (!tclCreatComm_ret) {"
puts "\t\treturn(TCL_ERROR);"
puts "\t}"
puts ""
puts "\ttclCreatComm_ret = Tcl_CreateObjCommand(interp, \"::vfs::kitdll::data::${hashkey}::getData\", getData, NULL, NULL);"
puts "\tif (!tclCreatComm_ret) {"
puts "\t\treturn(TCL_ERROR);"
puts "\t}"
puts ""
puts "\ttclCreatComm_ret = Tcl_CreateObjCommand(interp, \"::vfs::kitdll::data::${hashkey}::getChildren\", getChildren, NULL, NULL);"
puts "\tif (!tclCreatComm_ret) {"
puts "\t\treturn(TCL_ERROR);"
puts "\t}"
puts ""
puts "\ttclPkgProv_ret = Tcl_PkgProvide(interp, \"vfs::kitdll::data::${hashkey}\", \"1.0\");"
puts ""
puts "\treturn(tclPkgProv_ret);"
puts "\t}"
puts "#  endif /* KITDLL_MAKE_LOADABLE */"

puts "#endif /* !$cpp_tag */"
