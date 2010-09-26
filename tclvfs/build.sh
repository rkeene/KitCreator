#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TCLVFSVERS="20080503"
SRC="src/tclvfs-${TCLVFSVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tclvfs/files/tclvfs/tclvfs-${TCLVFSVERS}/tclvfs-${TCLVFSVERS}.tar.gz/download"
BUILDDIR="$(pwd)/build/tclvfs-${TCLVFSVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export TCLVFSVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	wget -O "${SRC}" "${SRCURL}" || exit 1
fi

(
	cd 'build' || exit 1

	gzip -dc "../${SRC}" | tar -xf -

	cd "${BUILDDIR}" || exit 1
	./configure --disable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	cp generic/vfs.c .

	"${MAKE:-make}" || exit 1

	"${MAKE:-make}" install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/vfs*/ "${OUTDIR}/lib/"
	rm -f "${OUTDIR}/lib"/vfs*/*.a
) || exit 1

exit 0
