#! /usr/bin/env bash

TCLLIB_VERS='1.16'
SRC="src/tcllib-${TCLLIB_VERS}.tar.bz2"
SRCURL="http://sourceforge.net/projects/tcllib/files/tcllib/${TCLLIB_VERS}/Tcllib-${TCLLIB_VERS}.tar.bz2"
BUILDDIR="$(pwd)/build/Tcllib-${TCLLIB_VERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TCLLIB_VERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

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
		bzip2 -dc "../${SRC}" | tar -xf -
	else
		cp -rp ../buildsrc/* './'
	fi

	cd "${BUILDDIR}" || exit 1

	./configure --prefix="${INSTDIR}" || exit 1

	make || exit 1

	make install || exit 1

	cp -rp "${INSTDIR}/lib" "${OUTDIR}"
) || exit 1

