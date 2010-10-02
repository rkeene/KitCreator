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

	# Fix up archives that Tcl gets wrong
	for archive in ../../../tcl/inst/lib/dde*/tcldde*.a ../../../tcl/inst/lib/reg*/tclreg*.a; do
		if [ ! -f "${archive}" ]; then
			continue
		fi

		rm -rf __TEMP__
		(
			mkdir __TEMP__ || exit 1
			cd __TEMP__

			## Patch archive name
			archive="../${archive}"

			"${AR:-ar}" x "${archive}" || exit 1

			rm -f "${archive}"

			"${AR:-ar}" cr "${archive}" *.o || exit 1
			"${RANLIB:-ranlib}" "${archive}" || true
		)
	done

	# Determine how we invoke a Tcl interpreter
	for testsh in "${TCLSH_NATIVE:-false}" "${TCLKIT:-tclkit}"; do
		if echo 'exit 0' | "${testsh}" >/dev/null 2>/dev/null; then
			TCLSH_NATIVE="${testsh}"

			break
		fi
	done

	# Cleanup, just incase the incoming directory was not pre-cleaned
	${MAKE:-make} distclean >/dev/null 2>/dev/null
	rm -rf "starpack.vfs"

	# Create VFS directory
	mkdir "starpack.vfs"
	mkdir "starpack.vfs/lib"

	## Copy in required built directories
	cp -r "${OTHERPKGSDIR}"/*/out/* 'starpack.vfs/'

	## Rename the "vfs" package directory to what "boot.tcl" expects
	mv 'starpack.vfs/lib'/vfs* 'starpack.vfs/lib/vfs'

	## Install "boot.tcl"
	cp 'boot.tcl' 'starpack.vfs/'

	# Include extra objects as required
	## Initialize list of extra objects
	EXTRA_OBJS=""

	## Figure out if zlib compiled (if not, the system zlib will be used and we
	## will need to have that present)
	ZLIBDIR="$(cd "${OTHERPKGSDIR}/zlib/inst" 2>/dev/null && pwd)"
	export ZLIBDIR
	if [ -n "${ZLIBDIR}" -a -f "${ZLIBDIR}/lib/libz.a" ]; then
		EXTRA_OBJS="${EXTRA_OBJS} ${ZLIBDIR}/lib/libz.a"
	fi

	## Tk Resources (needed for Win32 support)
	TKDIR="$(cd "${OTHERPKGSDIR}/tk/inst" && pwd)"
	TKRSRC="${TKDIR}/lib/tkbase.res.o"
	if [ -n "${TKDIR}" -a -f "${TKRSRC}" ]; then
		EXTRA_OBJS="${EXTRA_OBJS} ${TKRSRC}"
	fi

	## Export to the environment, to be picked up by the "configure" script
	export EXTRA_OBJS

	# Build KitDLL
	echo "Running: ./configure --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} TCLSH_NATIVE="${TCLSH_NATIVE}" || exit 1

	# Strip the KitDLL of debugging symbols, if possible
	"${STRIP:-strip}" -g libtclkit* >/dev/null 2>/dev/null

	# Fix up Win32 DLL names
	## .DLL.A -> .LIB
	for file in libtclkit*.dll.a; do
		if [ ! -f "${file}" ]; then
			continue
		fi

		newfile="$(basename "${file}" .dll.a).lib"
		mv "${file}" "${newfile}"
	done

	## .DLL.DEF -> .DEF
	for file in libtclkit*.dll.def; do
		if [ ! -f "${file}" ]; then
			continue
		fi

		newfile="$(basename "${file}" .dll.def).def"
		mv "${file}" "${newfile}"
	done

	exit 0
) || exit 1

exit 0
