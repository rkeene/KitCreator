#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

# Preparation

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

# The dbus package

DBUSVERS="2.0"
SRC="src/dbus-${DBUSVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/dbus-tcl/files/dbus/${DBUSVERS}/dbus-${DBUSVERS}.tar.gz/download"
BUILDDIR="$(pwd)/build/dbus-${DBUSVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export DBUSVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_DBUS_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_DBUS_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_DBUS_CPPFLAGS}"
LIBS="${LIBS} ${KC_DBUS_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if [ ! -d 'buildsrc' ]; then
		download "${SRCURL}" "${SRC}" - || exit 1
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
	echo "Running: ./configure --prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} || exit 1

	echo "Running: ${MAKE:-make} install"
	${MAKE:-make} install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/dbus* "${OUTDIR}/lib/"

        "${STRIP:-strip}" -g "${OUTDIR}"/lib/dbus-*/*.so >/dev/null 2>/dev/null
	exit 0
) || exit 1

# The dbif module

DBIFVERS="1.0"
SRC="src/dbif-${DBIFVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/dbus-tcl/files/dbif/${DBIFVERS}/dbif-${DBIFVERS}.tar.gz/download"
BUILDDIR="$(pwd)/build/dbif-${DBIFVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export DBIFVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

# Set configure options for this sub-project
LDFLAGS="${KC_DBIF_LDFLAGS}"
CFLAGS="${KC_DBIF_CFLAGS}"
CPPFLAGS="${KC_DBIF_CPPFLAGS}"
LIBS="${KC_DBIF_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

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
	echo "Running: ./configure --prefix=\"${INSTDIR}\" moduledir=\"${INSTDIR}/lib/tcl8/8.5\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --prefix="${INSTDIR}" moduledir="${INSTDIR}/lib/tcl8/8.5" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	echo "Running: ${MAKE:-make}"
	${MAKE:-make} || exit 1

	echo "Running: ${MAKE:-make} install"
	${MAKE:-make} install

	mkdir -p "${OUTDIR}/lib/tcl8/8.5" || exit 1
	cp -r "${INSTDIR}/lib/tcl8/8.5/"dbif*.tm "${OUTDIR}/lib/tcl8/8.5/"
	exit 0
) || exit 1

exit 0
