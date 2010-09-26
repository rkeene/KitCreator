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
PATCHDIR="$(pwd)/patches"
export TCLVFSVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

TCL_VERSION="unknown"
if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
	source "${TCLCONFIGDIR}/tclConfig.sh"
fi
export TCL_VERSION

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	wget -O "${SRC}" "${SRCURL}" || exit 1
fi

(
	cd 'build' || exit 1

	gzip -dc "../${SRC}" | tar -xf -

	cd "${BUILDDIR}" || exit 1

        # Apply required patches
	for patch in "${PATCHDIR}/all"/tclvfs-${TCLVFSVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tclvfs-${TCLVFSVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done                                                                                                                               

	cp generic/vfs.c .

	# Build static version
	./configure --disable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
	${MAKE:-make} || exit 1
	${MAKE:-make} install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/vfs*/ "${OUTDIR}/lib/"
	rm -f "${OUTDIR}/lib"/vfs*/*.a "${OUTDIR}/lib"/vfs*/*.so

	exit 0
) || exit 1

exit 0
