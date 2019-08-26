#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='0.4'
url="https://chiselapp.com/user/stwo/repository/tcllux/uv/tcllux-${version}.tar.gz"
sha256='c4fecf6852b35089a8f6d0e1a6fe8feb70c5f7e9f4eb91ad6b4caa9c65c211fd'
pkg_ignore_opts=(--enable-threads --disable-threads)
pkg_no_support_for_static='1'

function postinstall() {
	(
		cd "${installdir}/lib" || exit 1
		if [ -d 'tcl' ]; then
			mv tcl/* .
			rmdir tcl
		fi
	) || return 1
}
