#! /bin/bash

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
export ITCLVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	rm -f "${SRC}.tmp"
	wget -O "${SRC}.tmp" "${SRCURL}" || exit 1
	mv "${SRC}.tmp" "${SRC}"
fi

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
	else    
		cp -rp ../buildsrc/* './'
	fi

	cd "${BUILDDIR}" || exit 1
	./configure --enable-shared --disable-symbols --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	${MAKE:-make} || exit 1

	${MAKE:-make} install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/thread*/ "${OUTDIR}/lib/"

	"${STRIP:-strip}" -g "${OUTDIR}"/lib/thread*/*.so >/dev/null 2>/dev/null

	exit 0
) || exit 1

exit 0
