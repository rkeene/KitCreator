#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

MEMCHANVERS="2.2.1"
SRC="src/memchan-${MEMCHANVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/memchan/files/memchan/${MEMCHANVERS}/memchan-${MEMCHANVERS}.tar.gz/download"
BUILDDIR="$(pwd)/build/memchan-${MEMCHANVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export MEMCHANVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

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

	# This fixes a well-known, long-standing failure in many Tcl
	# configure scripts
	sed "s@ /etc/\\.relid'@ '/etc/.relid'@" configure > configure.new
	cat configure.new > configure
	rm -f configure.new

	cd generic || exit 1

	../configure --enable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	"${MAKE:-make}" || exit 1

	"${MAKE:-make}" install
) || exit 1

exit 0
