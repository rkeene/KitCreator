#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.2"
url="https://chiselapp.com/user/rkeene/repository/tcl-nano/uv/releases/tcl-nano-${version}.tar.gz"
sha256='84465093c491ab8ae7cf3db2c330e010691ac558ab830f096ca8cb7fe0222338'
configure_extra=(--enable-stubs)

function preconfigure() {
	sed -i 's@stack-protector-all@donot-stack-protector-all@g' configure
}

function postinstall() {
	rm -f "${installdir}/lib/tcl-nano${version}/nano.man"
	if [ -f "${installdir}/lib/tcl-nano${version}/nano.lib" -a ! -f "${installdir}/lib/tcl-nano${version}/nano.a" ]; then
		mv "${installdir}/lib/tcl-nano${version}/nano.lib" "${installdir}/lib/tcl-nano${version}/nano.a"
	fi
}
