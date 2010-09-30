#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

KITDLLVERS="0.0"
BUILDDIR="$(pwd)/build/kitdll-${KITDLLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
OTHERPKGSDIR="$(pwd)/../"
export KITDLLVERS BUILDDIR OUTDIR INSTDIR OTHERPKGSDIR

rm -rf 'build' 'out' 'inst'
mkdir 'out' 'inst' || exit 1

(
	cp -r 'buildsrc' 'build'
	cd "${BUILDDIR}" || exit 1

	# Determine how we invoke a Tcl interpreter
	for testsh in "${TCLSH_NATIVE:-false}" "${TCLKIT:-tclkit}"; do
		if echo 'exit 0' | "${testsh}" >/dev/null 2>/dev/null; then
			TCLSH_NATIVE="${testsh}"

			break
		fi
	done

	# Cleanup, just incase the incoming directory was not pre-cleaned
	${MAKE:-make} distclean >/dev/null 2>/dev/null

	echo "Running: ./configure --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} TCLSH_NATIVE="${TCLSH_NATIVE}" || exit 1

	# Strip the KitDLL of debugging symbols, if possible
	"${STRIP:-strip}" -g libtcl.* >/dev/null 2>/dev/null

	# Create VFS directory
	mkdir "starpack.vfs"
	mkdir "starpack.vfs/lib"

	## Copy in required built directories
	cp -r "${OTHERPKGSDIR}"/tcl/out/* 'starpack.vfs/'
	cp -r "${OTHERPKGSDIR}"/tclvfs/out/* 'starpack.vfs/'
	cp -r "${OTHERPKGSDIR}"/thread/out/* 'starpack.vfs/'

	## Rename the "vfs" package directory to what "boot.tcl" expects
	mv 'starpack.vfs/lib'/vfs* 'starpack.vfs/lib/vfs'

	## Install "boot.tcl"
	cp 'boot.tcl' 'starpack.vfs/'

	exit 0
) || exit 1

exit 0
