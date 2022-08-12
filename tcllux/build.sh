#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='0.5'
url="https://chiselapp.com/user/stwo/repository/tcllux/uv/tcllux-${version}.tar.gz"
sha256='c5100f784b0790f878f75dbdadc109f69e3cee536eb9376785a360284345d4fe'
pkg_ignore_opts=(--enable-threads --disable-threads --enable-kit-storage)
pkg_no_support_for_static='1'

function postinstall_() {
	(
		cd "${installdir}/lib" || exit 1
		if [ -d 'tcl' ]; then
			mv tcl/* .
			rmdir tcl
		fi
	) || return 1
}
