#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="0.30"
url="http://rkeene.org/devel/tcc4tcl/tcc4tcl-${version}.tar.gz"
sha256='f120e8e0d87c87c1775215dbede1de4633bdfce61a354fb7976da8870a311937'
configure_extra=()

function preconfigure() {
	configure_extra=("${configure_extra[@]}" "--enable-stubs")
	if echo " ${CONFIGUREEXTRA} " | grep ' --disable-load ' >/dev/null; then
		configure_extra=("${configure_extra[@]}" "--with-dlopen")
	else
		configure_extra=("${configure_extra[@]}" "--without-dlopen")
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
