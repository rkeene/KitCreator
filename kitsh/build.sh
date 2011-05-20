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

if [ -z "${ENABLECOMPRESSION}" ]; then
	ENABLECOMPRESSION="1"
fi
export ENABLECOMPRESSION

rm -rf 'build' 'out' 'inst'
mkdir 'out' 'inst' || exit 1


(
	cp -r 'buildsrc' 'build'
	cd "${BUILDDIR}" || exit 1

	# Cleanup, just incase the incoming directory was not pre-cleaned
	${MAKE:-make} distclean >/dev/null 2>/dev/null

	# Create VFS directory
	mkdir "starpack.vfs"
	mkdir "starpack.vfs/lib"

	## Copy in all built directories
	cp -r "${OTHERPKGSDIR}"/*/out/* 'starpack.vfs/'

	## Rename the "vfs" package directory to what "boot.tcl" expects
	mv 'starpack.vfs/lib'/vfs* 'starpack.vfs/lib/vfs'

	## Install "boot.tcl"
	cp 'boot.tcl' 'starpack.vfs/'

	# Figure out if zlib compiled (if not, the system zlib will be used and we
	# will need to have that present)
	ZLIBDIR="$(cd "${OTHERPKGSDIR}/zlib/inst" 2>/dev/null && pwd)"
	export ZLIBDIR
	if [ -z "${ZLIBDIR}" -o ! -f "${ZLIBDIR}/lib/libz.a" ]; then
		unset ZLIBDIR
	fi

	# Copy user specified kit.rc and kit.ico in to build directory, if found
	cp "${KITCREATOR_ICON}" "${BUILDDIR}/kit.ico"
	cp "${KITCREATOR_RC}" "${BUILDDIR}/kit.rc"

	# Include extra objects as required
	## Initialize list of extra objects
	EXTRA_OBJS=""

	## Tk Resources (needed for Win32 support) -- remove kit-found resources to prevent the symbols from being in conflict
	TKDIR="$(cd "${OTHERPKGSDIR}/tk/inst" && pwd)"
	TKRSRC="${TKDIR}/lib/tkbase.res.o"
	if [ -n "${TKDIR}" -a -f "${TKRSRC}" ]; then
		EXTRA_OBJS="${EXTRA_OBJS} ${TKRSRC}"

		echo ' *** Removing "kit.rc" since we have Tk with its own resource file'

		rm -f "${BUILDDIR}/kit.rc"
	fi

	## Export to the environment, to be picked up by the "configure" script
	export EXTRA_OBJS

	# Compile Kitsh
	if [ -z "${ZLIBDIR}" ]; then
		echo "Running: ./configure --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"

		./configure --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
	else
		echo "Running: ./configure --with-tcl=\"${TCLCONFIGDIR}\" --with-zlib=\"${ZLIBDIR}\" ${CONFIGUREEXTRA}"

		./configure --with-tcl="${TCLCONFIGDIR}" --with-zlib="${ZLIBDIR}" ${CONFIGUREEXTRA}
	fi

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} || exit 1

	# Strip the kit of all symbols, if possible
	"${STRIP:-strip}" kit >/dev/null 2>/dev/null

	# Intall VFS onto kit
	## Determine if we have a Tclkit to do this work
	TCLKIT="${TCLKIT:-tclkit}"
	if echo 'exit 0' | "${TCLKIT}" >/dev/null 2>/dev/null; then
		## Install using existing Tclkit
		### Call installer
		echo "Running: \"${TCLKIT}\" installvfs.tcl kit starpack.vfs \"${ENABLECOMPRESSION}\""
		"${TCLKIT}" installvfs.tcl kit starpack.vfs "${ENABLECOMPRESSION}"
	else
		## Bootstrap (cannot cross-compile)
		### Call installer
		cp kit runkit
		echo "set argv [list kit starpack.vfs {${ENABLECOMPRESSION}}]" > setup.tcl
		echo 'if {[catch { clock seconds }]} { proc clock args { return 0 } }' >> setup.tcl
		echo 'source installvfs.tcl' >> setup.tcl

		echo 'Running: echo | ./runkit'
		echo | ./runkit
	fi

	exit 0
) || exit 1

exit 0
