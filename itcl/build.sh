#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

ITCLVERS="3.4"
ITCLVERSEXTRA="b1"
SRC="src/itcl-${ITCLVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/incrtcl/files/%5BIncr%20Tcl_Tk%5D-source/${ITCLVERS}/itcl${ITCLVERS}${ITCLVERSEXTRA}.tar.gz/download"
BUILDDIR="$(pwd)/build/itcl${ITCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export ITCLVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

# Determine if Itcl is even needed
(
	TCL_VERSION="unknown"
	if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
		source "${TCLCONFIGDIR}/tclConfig.sh"
	fi

	if echo "${TCL_VERSION}" | grep '^8\.[45]$' >/dev/null; then
		# Itcl is required for Tcl 8.4 and Tcl 8.5

		exit 0
	fi

	if [ "${TCL_VERSION}" = "unknown" ]; then
		# If we don't know what version of Tcl we are building, build
		# Itcl just in case.

		exit 0
	fi

	# All other versions do not require Itcl
	echo "Skipping building Itcl, not required for ${TCL_VERSION}"
	exit 1
) || exit 0

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	wget -O "${SRC}" "${SRCURL}" || exit 1
fi

(
	cd 'build' || exit 1

	gzip -dc "../${SRC}" | tar -xf -

	cd "${BUILDDIR}" || exit 1
	./configure --enable-shared --disable-symbols --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	"${MAKE:-make}" || exit 1

	"${MAKE:-make}" install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/itcl*/ "${OUTDIR}/lib/"

	strip -g "${OUTDIR}"/lib/itcl*/*.so >/dev/null 2>/dev/null

	exit 0
) || exit 1

exit 0
