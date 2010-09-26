#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

SRC="src/tcl${TCLVERS}.tar.gz"
SRCURL="http://prdownloads.sourceforge.net/tcl/tcl${TCLVERS}-src.tar.gz"
BUILDDIR="$(pwd)/build/tcl${TCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if echo "${TCLVERS}" | grep '^cvs_' >/dev/null; then
		CVSTAG=$(echo "${TCLVERS}" | sed 's/^cvs_//g')
		export CVSTAG

		(
			cd src || exit 1

			cvs -z3 -d:pserver:anonymous@tcl.cvs.sourceforge.net:/cvsroot/tcl co -r "${CVSTAG}" -P tcl

			mv tcl "tcl${TCLVERS}"

			tar -cf - "tcl${TCLVERS}" | gzip -c > "../${SRC}"
		)
	else
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
	for dir in unix win macosx; do
		# Remove previous directory's "tclConfig.sh" if found
		rm -f 'tclConfig.sh'

		cd "${BUILDDIR}/${dir}" || exit 1

		./configure --disable-shared --prefix="${INSTDIR}" ${CONFIGUREEXTRA}

		${MAKE:-make} || continue

		${MAKE:-make} install

		mkdir "${OUTDIR}/lib" || exit 1
		cp -r "${INSTDIR}/lib"/* "${OUTDIR}/lib/"
		rm -rf "${OUTDIR}/lib/pkgconfig"
		rm -f "${OUTDIR}"/lib/* >/dev/null 2>/dev/null
		find "${OUTDIR}" -name '*.a' | xargs rm -f >/dev/null 2>/dev/null

		break
	done
) || exit 1

exit 0
