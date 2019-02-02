#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='0.6.0'
url="https://github.com/dbohdan/tcl-duktape/archive/v${version}.tar.gz"
sha256='14d52c0ab6445e00217046d5a6b09406776e74fd35147003d7b9bbbcc6b40668'
tclpkg_initfunc='Tclduktape_Init'

# tcl-duktape does not ship complete releases :-(
function preconfigure() {
	if [ ! -e configure ]; then
		./autogen.sh
	fi
	sed -i 's@Tclduktape_Init@Tclduktape@g' lib/pkgIndex.tcl.in
}
