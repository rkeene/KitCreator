#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="0.26"
url="http://rkeene.org/devel/tcc4tcl/tcc4tcl-${version}.tar.gz"
sha256='8116d2ab94cc611c4e0be81e34bd8cc11a6f3e1fd49d02d7e894bbadcfffde0b'

function preconfigure() {
	if echo " ${CONFIGUREEXTRA} " | grep ' --disable-load ' >/dev/null; then
		configure_extra=("--with-dlopen")
	else
		configure_extra=("--without-dlopen")
	fi
}

function postinstall() {
	echo "/libtcc1\.a" > "${installdir}/kitcreator-nolibs"
}

function createruntime() {
	local filename

	# Create VFS-insert
	mkdir -p "${runtimedir}" || return 1
	cp -r "${installdir}/lib" "${runtimedir}" || return 1

	find "${runtimedir}" -name '*.a' -type f | grep -v '/libtcc1\.a$' | while IFS='' read -r filename; do
		rm -f "${filename}"
	done
}
