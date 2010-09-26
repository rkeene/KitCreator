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
	./configure --with-tcl="${TCLCONFIGDIR}"
	${MAKE:-make} || exit 1

	strip kit >/dev/null 2>/dev/null

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
	if echo 'exit 0' | tclkit >/dev/null 2>/dev/null; then
		## Install using existing Tclkit
		### Call installer
		tclkit installvfs.tcl kit starpack.vfs
	else
		## Bootstrap (cannot cross-compile)
		### Call installer
		cp kit runkit
		echo 'set argv [list kit starpack.vfs]' > setup.tcl
		echo 'source installvfs.tcl' >> setup.tcl
		echo | ./runkit
	fi

	exit 0
) || exit 1

exit 0
