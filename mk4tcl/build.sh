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
PATCHDIR="$(pwd)/patches"
export MK4VERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

TCL_VERSION="unknown"
if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
        source "${TCLCONFIGDIR}/tclConfig.sh"
fi
export TCL_VERSION

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

	# Apply required patches
	cd "${BUILDDIR}" || exit 1
	for patch in "${PATCHDIR}/all"/metakit-${MK4VERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/metakit-${MK4VERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done

	cd "${BUILDDIR}/unix" || exit 1

	# Build static libraries for linking against Tclkit
	./configure --disable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}/../generic" ${CONFIGUREEXTRA}
	${MAKE:-make} tcllibdir="${INSTDIR}/lib" || exit 1
	${MAKE:-make} tcllibdir="${INSTDIR}/lib" install

	exit 0
) || exit 1

exit 0
