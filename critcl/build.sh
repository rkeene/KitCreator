#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='3.1.18.1'
url="http://github.com/andreas-kupries/critcl/tarball/${version}/critcl-${version}.tar.gz"
sha256='c26893bda46dfda332d2e7d7410ae998eafda697169ea25b4256295d293089de'
deps_dir="$(pwd)/deps"

function configure() {
	:
}

function build() {
	:
}

function install() {
	local tclmajminvers
	local critcl_cdir
	local critcl_target_info

	# Setup cross-compilation in the way Critcl expects, as best as possible
	if [ "${KC_CROSSCOMPILE}" = '0' ]; then
		critcl_target_info=()
	else
		critcl_target_info=(-target)
		case "${KC_CROSSCOMPILE_HOST_OS}" in
			aarch64-*-linux|aarch64-*-linux-*)
				critcl_target_info+=('linux-64-aarch64')
				;;
			arm-*-linux-*|arm-*-linux)
				critcl_target_info+=('linux-arm')
				;;
			i?86-*-linux-*|i?86-*-linux)
				critcl_target_info+=('linux-32-x86')
				;;
			hppa64-*-hpux*)
				critcl_target_info+=('hpux-parisc64-cc')
				;;
			i?86-*-solaris2.*)
				critcl_target_info+=('solaris-ix86-cc')
				#critcl_target_info+=('solaris-x86_64-cc')
				;;
			i?86-*-mingw32*)
				critcl_target_info+=('mingw32')
				;;
			x86_64-*-mingw32*)
				critcl_target_info+=('mingw32')
				;;
			mips-*-linux-*|mips-*-linux|mipsel-*-linux-*|mipsel-*-linux|mipseb-*-linux-*|mipseb-*-linux)
				critcl_target_info+=('linux-32-mips')
				;;
			powerpc-*-aix*)
				critcl_target_info+=('aix-powerpc-cc')
				;;
			sparc-*-solaris2.*)
				critcl_target_info+=('solaris-sparc-cc')
				#critcl_target_info+=('solaris-sparc64-cc')
				;;
			x86_64-*-linux-*|x86_64-*-linux)
				critcl_target_info+=('linux-64-x86_64')
				;;
			*)
				echo "error: Critcl does not support cross-compiling to ${KC_CROSSCOMPILE_HOST_OS}" >&2
				return 1
				;;
		esac
	fi

	# Include our Tcl packages directory, to ensure Critcl can be run
	export TCLLIBPATH="${deps_dir}"

	# Call the Critcl installer
	mkdir -p "${installdir}/lib" || return 1
	"${TCLSH_NATIVE}" ./build.tcl install "${critcl_target_info[@]}" "${installdir}/lib" || return 1

	# Critcl returns success even if it fails, so we need to double-check its work
	if [ "${KC_CROSSCOMPILE}" = '0' ]; then
		if [ ! -d "$(echo "${installdir}"/lib/*md5c*/)" ]; then
			return 1
		fi
	fi

	# We only need to keep headers for a single version of Tcl, the one the kit was compiled
	# for
	tclmajminvers="$(echo "${TCLVERS}" | cut -f 1-2 -d .)"
	critcl_cdir="$(echo "${installdir}/lib"/critcl*/critcl_c)"

	mv "${critcl_cdir}/tcl${tclmajminvers}" "${critcl_cdir}/.keep-tcl" || return 1
	rm -rf "${critcl_cdir}"/tcl*/
	mv "${critcl_cdir}/.keep-tcl" "${critcl_cdir}/tcl${tclmajminvers}" || return 1

	return 0
}
