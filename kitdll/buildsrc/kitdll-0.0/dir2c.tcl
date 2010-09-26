#! /usr/bin/env tclsh

if {[llength $argv] != 2} {
	puts stderr "Usage: dir2c <hashkey> <startdir>"

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

	set ret [list]
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

			lappend ret $child

			continue
		}

		if {$childinfo(type) != "file"} {
			continue
		}

		lappend ret $child
	}

	return $ret
}

proc dir2c_hash {path} {
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

set files [recursive_glob $startdir]

set cpp_tag "DIR2C_[string toupper $hashkey]"
set code_tag "dir2c_[string tolower $hashkey]"

puts "#ifndef $cpp_tag"
puts "#  define $cpp_tag 1"
puts {#  include <unistd.h>

#  ifndef LOADED_DIR2C_COMMON
#    define LOADED_DIR2C_COMMON 1

typedef enum {
	DIR2C_FILETYPE_FILE,
	DIR2C_FILETYPE_DIR
} dir2c_filetype_t;

struct dir2c_data {
	const char            *name;
	unsigned long         index;
	unsigned long         size;
	dir2c_filetype_t      type;
	const unsigned char   *data;
};

static unsigned long dir2c_hash(const unsigned char *path) {
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

#  endif /* !LOADED_DIR2C_COMMON */}
puts ""

puts "static struct dir2c_data ${code_tag}_data\[\] = {"
puts "\t{"
puts "\t\t.name  = NULL,"
puts "\t\t.index = 0,"
puts "\t\t.type  = 0,"
puts "\t\t.size  = 0,"
puts "\t\t.data  = NULL,"
puts "\t},"
puts "\t{"
puts "\t\t.name  = \"\","
puts "\t\t.index = 1,"
puts "\t\t.type  = DIR2C_FILETYPE_DIR,"
puts "\t\t.size  = 0,"
puts "\t\t.data  = NULL,"
puts "\t},"
for {set idx 0} {$idx < [llength $files]} {incr idx} {
	set file [lindex $files $idx]
	set shortfile [shorten_file $startdir $file]

	unset -nocomplain finfo type
	file stat $file finfo

	switch -- $finfo(type) {
		"file" {
			set type "DIR2C_FILETYPE_FILE"
			set size $finfo(size)

			set fd [open $file]
			fconfigure $fd -translation binary
			set data [read $fd]
			close $fd

			set data [stringify $data]
		}
		"directory" {
			set type "DIR2C_FILETYPE_DIR"
			set data "NULL"
			set size 0
		}
	}

	puts "\t{"
	puts "\t\t.name  = \"$shortfile\","
	puts "\t\t.index = [expr $idx + 2],"
	puts "\t\t.type  = $type,"
	puts "\t\t.size  = $size,"
	puts "\t\t.data  = $data,"
	puts "\t},"
}
puts "};"
puts ""

puts "static unsigned long ${code_tag}_lookup_index(const char *path) {"
puts "\tswitch (dir2c_hash(path)) {"
puts "\t\tcase [dir2c_hash {}]:"
puts "\t\t\treturn(1);"

set seenhashes [list]
for {set idx 0} {$idx < [llength $files]} {incr idx} {
	set file [lindex $files $idx]
	set shortfile [shorten_file $startdir $file]
	set hash [dir2c_hash $shortfile]

	if {[lsearch -exact $seenhashes $hash] != -1} {
		puts stderr "ERROR: Duplicate hash seen: $file ($hash), aborting"

		exit 1
	}

	lappend seenhashes $hash

	puts "\t\tcase $hash:"
	puts "\t\t\treturn([expr $idx + 2]);"
}

puts "\t}"
puts "\treturn(0);"
puts "}"
puts ""

puts "static struct dir2c_data *${code_tag}_getData(const char *path) {"
puts "\tunsigned long index;"
puts ""
puts "\tindex = ${code_tag}_lookup_index(path);"
puts "\tif (index == 0) {"
puts "\t\treturn(NULL);"
puts "\t}"
puts ""
puts "\treturn(&${code_tag}_data\[index\]);"
puts "}"
puts ""

puts "#endif /* !$cpp_tag */"
