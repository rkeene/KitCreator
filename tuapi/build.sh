#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='0.6'
url="http://rkeene.org/devel/tuapi-${version}.tar.gz"
sha256='9e5d8cac9a6962b8afe9f88a0aa44303abbbfc5c0980d27ff7c0351a9c297d0b'

function configure() {
	:
}

function build() {
	(
		. build-common.sh

		eval ${TCL_CC} ${TCL_DEFS} ${TCL_INCLUDE_SPEC} -o tuapi.o -c tuapi.c || exit 1

		${AR:-ar} rcu libtuapi.a tuapi.o || exit 1

		${RANLIB:-ranlib} libtuapi.a || exit 1

		echo 'package ifneeded tuapi '"${tuapi_version}"' [list load {} tuapi]' > pkgIndex.tcl
	) || return 1
}

function install() {
	mkdir -p "${installdir}/lib/tuapi${version}" || return 1

	cp libtuapi.a pkgIndex.tcl "${installdir}/lib/tuapi${version}" || return 1
}
