#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TCLXVERS="8.4.1"
SRC="src/tclx${TCLXVERS}.tar.bz2"
SRCURL="http://sourceforge.net/projects/tclx/files/TclX/${TCLXVERS}/tclx${TCLXVERS}.tar.bz2/download"
SRCHASH='-'
BUILDDIR="$(pwd)/build/tclx8.4"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TCLXVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_TCLX_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_TCLX_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_TCLX_CPPFLAGS}"
LIBS="${LIBS} ${KC_TCLX_LIBS}"
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
		bzip2 -dc "../${SRC}" | tar -xf -
	else    
		cp -rp ../buildsrc/* './'
	fi

	# Apply required patches
	cd "${BUILDDIR}" || exit 1
	for patch in "${PATCHDIR}/all"/tclx-${TCLXVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tclx-${TCLXVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done

	cd "${BUILDDIR}" || exit 1

	# Try to build as a shared object if requested
	if [ "${STATICTCLX}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTCLX}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	SAVE_CFLAGS="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		rm -rf "${INSTDIR}"
		mkdir "${INSTDIR}"

		if [ "${tryopt}" = "__fail__" ]; then
			exit 1
		fi

		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static TclX for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${SAVE_CFLAGS} -fPIC"
		else
			CFLAGS="${SAVE_CFLAGS}"
		fi
		export CFLAGS

		if [ "${isshared}" = '0' ]; then
			sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' configure > configure.new
		else
			sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' configure > configure.new
		fi
		cat configure.new > configure
		rm -f configure.new

		(
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" AR=\"${AR:-ar}\" RANLIB=\"${RANLIB:-ranlib}\""
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" AR="${AR:-ar}" RANLIB="${RANLIB:-ranlib}" || exit 1

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" AR=\"${AR:-ar}\" RANLIB=\"${RANLIB:-ranlib}\" install"
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" AR="${AR:-ar}" RANLIB="${RANLIB:-ranlib}" install || exit 1
		) || continue

		break
	done

	if [ ! -e "${INSTDIR}/lib/tclx8.4/pkgIndex.tcl" ]; then
		cat << _EOF_ > "${INSTDIR}/lib/tclx8.4/pkgIndex.tcl"
package ifneeded Tclx 8.4 [list load {} Tclx]
_EOF_
        fi

	# Install files needed by installation
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | xargs -n 1 rm -f --

	exit 0
) || exit 1

exit 0
