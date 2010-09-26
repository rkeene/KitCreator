#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

ZLIBVERS="1.2.3"
SRC="src/zlib-${ZLIBVERS}.tar.gz"
SRCURL="http://www.zlib.net/zlib-${ZLIBVERS}.tar.gz"
BUILDDIR="$(pwd)/build/zlib-${ZLIBVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export ZLIBVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

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
	# We don't pass CONFIGUREEXTRA here, since this isn't a GNU autoconf
	# script and will puke
	./configure --prefix="${INSTDIR}"

	${MAKE:-make} || exit 1

	${MAKE:-make} install

	# We don't really care too much about failure in zlib
	exit 0
) || exit 1

exit 0
