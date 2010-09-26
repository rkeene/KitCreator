#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

SRC="src/tk${TCLVERS}.tar.gz"
SRCURL="http://prdownloads.sourceforge.net/tcl/tk${TCLVERS}-src.tar.gz"
BUILDDIR="$(pwd)/build/tk${TCLVERS}"
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

			cvs -z3 -d:pserver:anonymous@tcl.cvs.sourceforge.net:/cvsroot/tktoolkit co -r "${CVSTAG}" -P tk

			mv tk "tk${TCLVERS}"

			tar -cf - "tk${TCLVERS}" | gzip -c > "../${SRC}"
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
		# Remove previous directory's "tkConfig.sh" if found
		rm -f 'tkConfig.sh'

		cd "${BUILDDIR}/${dir}" || exit 1

		if [ "${dir}" != "win" ]; then
			# Statically link Tk to Tclkit if we are compiling for
			# Windows
			STATICTK="1"
		fi

		if [ "${STATICTK}" = "1" ]; then
			./configure --disable-shared --disable-symbols --prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
		else
			./configure --enable-shared --disable-symbols --prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
		fi

		${MAKE:-make} || continue

		${MAKE:-make} install

		# Update pkgIndex to load libtk from the local directory rather
		# than the parent directory
		for pkgIndex in "${INSTDIR}"/lib/tk*/pkgIndex.tcl; do
			sed 's@ \.\. @ @g' "${pkgIndex}" > "${pkgIndex}.new"
			mv "${pkgIndex}.new" "${pkgIndex}"
		done

		mkdir "${OUTDIR}/lib" || exit 1
		cp -r "${INSTDIR}/lib"/tk*/ "${OUTDIR}/lib/"
		cp -r "${INSTDIR}/lib"/libtk* "${OUTDIR}/lib"/tk*/
		rm -rf "${OUTDIR}/lib"/tk*/demos

		strip -g "${OUTDIR}"/lib/tk*/*.so >/dev/null 2>/dev/null
		find "${OUTDIR}" -type f -name '*.a' | xargs rm -f >/dev/null 2>/dev/null

		break
	done

	exit 0
) || exit 1

exit 0
