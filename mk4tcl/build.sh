#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

MK4VERS="2.4.9.7"
SRC="src/metakit-${MK4VERS}.tar.gz"
SRCURL="http://www.equi4.com/pub/mk/metakit-${MK4VERS}.tar.gz"
BUILDDIR="$(pwd)/build/metakit-${MK4VERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export MK4VERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	wget -O "${SRC}" "${SRCURL}" || exit 1
fi

(
	cd 'build' || exit 1

	gzip -dc "../${SRC}" | tar -xf -

	cd "${BUILDDIR}/unix" || exit 1
	./configure --disable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}/../generic" ${CONFIGUREEXTRA}

	"${MAKE:-make}" tcllibdir="${INSTDIR}/lib" || exit 1

	"${MAKE:-make}" tcllibdir="${INSTDIR}/lib" install
) || exit 1

exit 0
