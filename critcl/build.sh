#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='3.1.18.1'
url="http://github.com/andreas-kupries/critcl/tarball/${version}/critcl-${version}.tar.gz"
sha256='c26893bda46dfda332d2e7d7410ae998eafda697169ea25b4256295d293089de'

function configure() {
	:
}

function build() {
	:
}

function install() {
	local tclmajminvers
	local critcl_cdir

	mkdir -p "${installdir}/lib" || return 1

	tclmajminvers="$(echo "${TCLVERS}" | cut -f 1-2 -d .)"

	"${TCLSH_NATIVE}" ./build.tcl install "${installdir}/lib" || return 1

	critcl_cdir="$(echo "${installdir}/lib"/critcl*/critcl_c)"

	mv "${critcl_cdir}/tcl${tclmajminvers}" "${critcl_cdir}/.keep-tcl" || return 1
	rm -rf "${critcl_cdir}"/tcl*/
	mv "${critcl_cdir}/.keep-tcl" "${critcl_cdir}/tcl${tclmajminvers}" || return 1

	return 0
}
