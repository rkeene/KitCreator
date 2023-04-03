#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

BUILDDIR="$(pwd)/build/vqtcl"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
OTHERPKGSDIR="$(pwd)/../"
export BUILDDIR OUTDIR INSTDIR OTHERPKGSDIR

# Set configure options for this sub-project
LDFLAGS_ADD="${KC_VQTCL_LDFLAGS_ADD}"
LDFLAGS="${LDFLAGS} ${KC_VQTCL_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_VQTCL_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_VQTCL_CPPFLAGS}"
LIBS="${LIBS} ${KC_VQTCL_LIBS}"
export LDFLAGS_ADD LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'out' 'inst' || exit 1

(
	cp -rp 'buildsrc' 'build'
	cd "${BUILDDIR}" || exit 1

	if [ "${KITTARGET}" = "kitdll" ]; then
		CFLAGS="${CFLAGS} -fPIC"
		export CFLAGS
	fi

	echo "Running: ./configure --disable-shared --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
	./configure --disable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA} || continue

	echo "Running: ${MAKE:-make} install"
	${MAKE:-make} install || continue

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/* "${OUTDIR}/lib/"
	find "${OUTDIR}" -name '*.a' | xargs rm -f >/dev/null 2>/dev/null
) || exit 1

exit 0
