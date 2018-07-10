#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.0"
url="https://chiselapp.com/user/rkeene/repository/tcl-nano/uv/releases/tcl-nano-${version}.tar.gz"
sha256='16b599cf12b1dd2e1c74eb0a4382b933a5e1519144158360ff78bf161e14bca5'
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
