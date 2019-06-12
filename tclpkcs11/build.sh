#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="0.9.13"
url="https://chiselapp.com/user/rkeene/repository/tclpkcs11/uv/releases/tclpkcs11-${version}.tar.gz"
sha256='77a1e6328bb973b254e9f41e3bc711cf8fa95ae0d462ad50272acbef06d548d5'
configure_extra=()

function postinstall() {
	if [ -f "${installdir}/lib/tclpkcs11${version}/tclpkcs11.lib" -a ! -f "${installdir}/lib/tclpkcs11${version}/tclpkcs11.a" ]; then
		mv "${installdir}/lib/tclpkcs11${version}/tclpkcs11.lib" "${installdir}/lib/tclpkcs11${version}/tclpkcs11.a"
	fi
}
