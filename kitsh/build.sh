#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

KITSHVERS="0.0"
BUILDDIR="$(pwd)/build/kitsh-${KITSHVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
OTHERPKGSDIR="$(pwd)/../"
export KITSHVERS BUILDDIR OUTDIR INSTDIR OTHERPKGSDIR

rm -rf 'build' 'out' 'inst'
mkdir 'out' 'inst' || exit 1


(
	cp -r 'buildsrc' 'build'
	cd "${BUILDDIR}" || exit 1

	# Compile all objects...
	## XXX
	${CC:-cc} -I${TCLCONFIGDIR} -I${TCLCONFIGDIR}/../generic -o kit *.c $(find "${OTHERPKGSDIR}" -name '*.a' | grep '/inst/') -lz -lm -ldl  -Wl,-Bstatic -lstdc++ -Wl,-Bdynamic

	# Create VFS directory
	mkdir "starpack.vfs"
	mkdir "starpack.vfs/lib"

	## Copy in all built directories
	cp -r "${OTHERPKGSDIR}"/*/out/* 'starpack.vfs/'

	## Rename the "vfs" package directory to what "boot.tcl" expects
	mv 'starpack.vfs/lib'/vfs* 'starpack.vfs/lib/vfs'

	## Install "boot.tcl"
	cp 'boot.tcl' 'starpack.vfs/'

	# Intall VFS onto kit
	## Copy installed data for packages
	mkdir "installed-pkgs"
	cp -r "${OTHERPKGSDIR}"/*/inst/* 'installed-pkgs/'

	## Call installer
	${TCLCONFIGDIR}/tclsh installvfs.tcl kit starpack.vfs

) || exit 1

exit 0
