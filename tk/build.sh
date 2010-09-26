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
PATCHDIR="$(pwd)/patches"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export SRC SRCURL BUILDDIR PATCHDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

# Determine Tcl version
TCL_VERSION="unknown"
if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
	source "${TCLCONFIGDIR}/tclConfig.sh"
fi
export TCL_VERSION


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

	# Determine Tk version
	TK_VERSION="$(grep '^#.*define.*TK_VERSION' generic/tk.h 2>/dev/null | sed 's@^# *define[[:space:]][[:space:]]*TK_VERSION[[:space:]][[:space:]]*\"@@;s@\"$@@' 2>/dev/null | head -n 1)"
	if [ -z "${TK_VERSION}" ]; then
		TK_VERSION="unknown"
	fi
	export TK_VERSION

	echo "Note: TCL_VERSION=\"${TCL_VERSION}\""
	echo "Note: TK_VERSION=\"${TK_VERSION}\""

	(
		# Apply required patches
		cd "${BUILDDIR}" || exit 1
		for patch in "${PATCHDIR}/all"/tk-${TK_VERSION}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tk-${TK_VERSION}-*.diff; do
			if [ ! -f "${patch}" ]; then
				continue
			fi

			echo "Applying: ${patch}"
			${PATCH:-patch} -p1 < "${patch}"
		done
	)

	for dir in unix win macosx win64 __fail__; do
		if [ "${dir}" = "__fail__" ]; then
			exit 1
		fi

		# Windows/amd64 workarounds
		win64="0"
		if [ "${dir}" = "win64" ]; then
			win64="1"
			dir="win"
		fi

		# Remove previous directory's "tkConfig.sh" if found
		rm -f 'tkConfig.sh'

		cd "${BUILDDIR}/${dir}" || exit 1

		if [ "${dir}" = "win" ]; then
			# Statically link Tk to Tclkit if we are compiling for
			# Windows
			STATICTK="1"

			if [ "${win64}" = "1" ]; then
				# Mingw32 for AMD64 requires this, apparently
				CPPFLAGS="${CPPFLAGS} -D_WIN32_IE=0x0501"
				CFLAGS="${CFLAGS} -D_WIN32_IE=0x0501"
				export CPPFLAGS CFLAGS
			fi
		fi

		if [ "${STATICTK}" = "1" ]; then
			echo "Running: ./configure --disable-shared --disable-symbols --prefix=\"${INSTDIR}\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure --disable-shared --disable-symbols --prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
		else
			echo "Running: ./configure --enable-shared --disable-symbols --prefix=\"${INSTDIR}\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure --enable-shared --disable-symbols --prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}
		fi

		echo "Running: ${MAKE:-make}"
		${MAKE:-make} || continue

		echo "Running: ${MAKE:-make} install"
		${MAKE:-make} install || continue

		# Update to include resources, if found
		if [ "${dir}" = "win" ]; then
			echo ' *** Creating tkbase.res.o to support Windows build'
			echo "\"${RC:-windres}\" -o tkbase.res.o  --define STATIC_BUILD --include \"./../generic\" --include \"${TCLCONFIGDIR}/../generic\" --include \"${TCLCONFIGDIR}\" --include \"./rc\" \"./rc/tk_base.rc\""
			"${RC:-windres}" -o tkbase.res.o  --define STATIC_BUILD --include "./../generic" --include "${TCLCONFIGDIR}/../generic" --include "${TCLCONFIGDIR}" --include "./rc" "./rc/tk_base.rc"

			if [ -f "tkbase.res.o" ]; then
				cp "tkbase.res.o" "${INSTDIR}/lib/"
			fi
		fi

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

		"${STRIP:-strip}" -g "${OUTDIR}"/lib/tk*/*.so >/dev/null 2>/dev/null
		find "${OUTDIR}" -type f -name '*.a' | xargs rm -f >/dev/null 2>/dev/null

		break
	done

	exit 0
) || exit 1

exit 0
