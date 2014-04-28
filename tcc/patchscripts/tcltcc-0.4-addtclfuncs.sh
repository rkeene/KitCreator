#! /bin/bash

function find_syms() {
	if [ -z "${NM}" ]; then
		if echo "${CC}" | sed 's@ .*$@@' | grep '[-]' >/dev/null; then
			NM="$(echo "${CC}" | sed 's@ .*$@@;s@\(.*\)-[^-]*$@\1-nm@')"
		else
			NM='nm'
		fi
	fi

	# "${NM}" "${LIBTCL}" | sed 's@:.*$@@' | sed 's@.* @@' | grep '^Tcl_' | sort -u | while read -r sym; do
	"${CC:-gcc}" ${CPPFLAGS} -E include/tcl.h  | grep '^ *extern.*Tcl_'| sed 's@^ *extern *@@;s@(.*@@;s@.* *\**  *@@'  | sort -u | grep '^Tcl_' | grep -v ';$' | while read -r sym; do
		echo "    TCCSYM($sym)"
	done
}

add="$(find_syms)"

awk -v add="${add}" '/TCCSyms tcc_syms.*=/{
	print
	print add
	next
} { print }' generic/tcc.h > generic/tcc.h.new
cat generic/tcc.h.new > generic/tcc.h
rm -f generic/tcc.h.new

exit 0
