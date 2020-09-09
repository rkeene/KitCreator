#! /usr/bin/env bash

# BuildCompatible: KitCreator

version='0.1'
fossiltag='2015-01-31'
url="https://chiselapp.com/user/kbk/repository/tclbdd/tarball/tclbdd-tmp.tar.gz?uuid=${fossiltag}"
sha256='ab09c6cc84d42dde3ddc190330ca0bcfe2987fe2c6f225f96010c26dd41ed0e0'

pkg_no_support_for_static='1'

function preconfigure() {
    
    cd "${workdir}" || exit 1

    if [ ! -d tclconfig ]; then

	if [ "${fossiltag}" = "trunk" ]; then
	    fossilid="${fossiltag}"
	else
	    fossilid="$(echo 'file stat configure finfo; set date $finfo(mtime); set date [expr {$date + 1}]; puts [clock format $date -format {%Y-%m-%dT%H:%M:%S}]' | TZ='UTC' "${TCLSH_NATIVE}")"
	fi
	
	"${_download}" "https://core.tcl.tk/tclconfig/tarball/tclconfig-fossil.tar.gz?uuid=${fossilid}" "${archivedir}/tmp-tclconfig.tar.gz" - || rm -f "tmp-tclconfig.tar.gz"
	gzip -dc "${archivedir}/tmp-tclconfig.tar.gz" | tar -xf -
	mv "tclconfig-fossil" "tclconfig"
	
    fi
}

# to-dos:
# - tclbdd does not support static kit builds: _TclTomMathInitializeStubs symbol not found
# - tclbdd has a runtime dependency on tcllib: grammar::aycock package (this cannot be signalled in KC)
