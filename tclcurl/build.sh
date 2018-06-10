#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='7.22.0'
url="https://github.com/flightaware/tclcurl-fa/archive/1fd1b4178a083f4821d0c45723605824fbcdb017.tar.gz"
sha256='5abad0f369205b8369819f3993a700bb452921bcab7f42056ef29a1adc3eb093'
tclpkg='TclCurl'

function postinstall() {
	if [ "${pkg_configure_shared_build}" = '0' ]; then
		(
			eval "$(grep '^PKG_LIBS=' config.log)" || exit 1
			find "${installdir}" -type f -name '*.a' | while IFS='' read -r filename; do
				echo "${PKG_LIBS}" > "${filename}.linkadd"
			done
		) || return 1

		cat << \_EOF_ | sed "s|@@VERSION@@|${version}|g"> "${installdir}/lib/TclCurl${version}/pkgIndex.tcl"
package ifneeded TclCurl @@VERSION@@ [list load {} TclCurl]\n[list source [file join $dir tclcurl.tcl]]
_EOF_
	fi
}
