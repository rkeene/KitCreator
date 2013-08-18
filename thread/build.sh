#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

THREADVERS="2.6.5"
SRC="src/thread-${THREADVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tcl/files/Thread%20Extension/${THREADVERS}/thread${THREADVERS}.tar.gz/download"
BUILDDIR="$(pwd)/build/thread${THREADVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export THREADVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

# Set configure options for this sub-project
LDFLAGS="${KC_THREAD_LDFLAGS}"
CFLAGS="${KC_THREAD_CFLAGS}"
CPPFLAGS="${KC_THREAD_CPPFLAGS}"
LIBS="${KC_THREAD_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

# Determine if Threads is even needed
(
	TCL_VERSION="unknown"
	if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
		source "${TCLCONFIGDIR}/tclConfig.sh"
	fi

	if echo "${TCL_VERSION}" | grep '^8\.[45]$' >/dev/null; then
		# Threads may be required for Tcl 8.4 and Tcl 8.5

                exit 0
        fi

	if [ "${TCL_VERSION}" = "unknown" ]; then
		# If we dont know what version of Tcl we are building, build
		# Threads just in case.

		exit 0
	fi

	# All other versions do not require Threads
	echo "Skipping building Threads, not required for ${TCL_VERSION}"
	exit 1
) || exit 0

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if [ ! -d 'buildsrc' ]; then
		rm -f "${SRC}.tmp"
		wget -O "${SRC}.tmp" "${SRCURL}" || exit 1
		mv "${SRC}.tmp" "${SRC}"
	fi
fi

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
	else
		cp -rp ../buildsrc/* './'
	fi

	cd "${BUILDDIR}" || exit 1
	echo "Running: ./configure --enable-shared --disable-symbols --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --enable-shared --disable-symbols --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} || exit 1

	echo "Running: ${MAKE:-make} install"
	${MAKE:-make} install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/thread*/ "${OUTDIR}/lib/"

	"${STRIP:-strip}" -g "${OUTDIR}"/lib/thread*/*.so >/dev/null 2>/dev/null

	exit 0
) || exit 1

exit 0
