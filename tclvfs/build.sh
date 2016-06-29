#! /usr/bin/env bash

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
SRCHASH='0d90362078c8f59347b14be377e9306336b6d25d147397f845e705a6fa1d38f2'
BUILDDIR="$(pwd)/build/tclvfs-${TCLVFSVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TCLVFSVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_TCLVFS_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_TCLVFS_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_TCLVFS_CPPFLAGS}"
LIBS="${LIBS} ${KC_TCLVFS_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

TCL_VERSION="unknown"
if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
	source "${TCLCONFIGDIR}/tclConfig.sh"
fi
export TCL_VERSION

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if [ ! -d 'buildsrc' ]; then
		download "${SRCURL}" "${SRC}" "${SRCHASH}" || exit 1
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

        # Apply required patches
	for patch in "${PATCHDIR}/all"/tclvfs-${TCLVFSVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tclvfs-${TCLVFSVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done                                                                                                                               

	cp generic/vfs.c .

	# If we are building for Win32, we need to define TEA_PLATFORM so that
	# the right private directory is found
	BUILDTYPE="$(basename "${TCLCONFIGDIR}")"
	if [ "${BUILDTYPE}" = "win" ]; then
		TEA_PLATFORM="windows"
		export TEA_PLATFORM

		CFLAGS="${CFLAGS} -I${TCLCONFIGDIR}"
		export CFLAGS
	fi

	# If we are building for KitDLL, compile with '-fPIC'
	if [ "${KITTARGET}" = "kitdll" ]; then
		CFLAGS="${CFLAGS} -fPIC"
		export CFLAGS
	fi

	# Build static version
	echo "Running: ./configure --disable-shared --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --disable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} || exit 1

	echo "Running: ${MAKE:-make} install"
	${MAKE:-make} install || exit 1

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/vfs* "${OUTDIR}/lib/"
	rm -f "${OUTDIR}/lib"/vfs*/*.a "${OUTDIR}/lib"/vfs*/*.so

	exit 0
) || exit 1

exit 0
