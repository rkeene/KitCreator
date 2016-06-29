#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TCLUDPVERS="1.0.11"
SRC="src/tcludp-${TCLUDPVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tcludp/files/tcludp/${TCLUDPVERS}/tcludp-${TCLUDPVERS}.tar.gz"
SRCHASH='a8a29d55a718eb90aada643841b3e0715216d27cea2e2df243e184edb780aa9d'
BUILDDIR="$(pwd)/build/tcludp"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TCLUDPVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_TCLUDP_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_TCLUDP_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_TCLUDP_CPPFLAGS}"
LIBS="${LIBS} ${KC_TCLUDP_LIBS}"
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

	# Try to build as a shared object if requested
	if [ "${STATICTCLUDP}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTCLUDP}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	SAVE_CFLAGS="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		rm -rf "${INSTDIR}"
		mkdir "${INSTDIR}"

		if [ "${tryopt}" = "__fail__" ]; then
			exit 1
		fi

		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static TCLUDP for KitDLL, ensure that we use PIC
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
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ac_cv_path_DTPLITE=no ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ac_cv_path_DTPLITE=no ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\""
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" || exit 1

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" install"
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" install || exit 1
		) || continue

		break
	done

	# Create pkgIndex if needed
	if [ ! -e "${INSTDIR}/lib/udp${TCLUDPVERS}/pkgIndex.tcl" ]; then
		cat << _EOF_ > "${INSTDIR}/lib/udp${TCLUDPVERS}/pkgIndex.tcl"
package ifneeded udp ${TCLUDPVERS} [list load {} udp]
_EOF_
	fi

	# Install files needed by installation
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | xargs -n 1 rm -f --

	exit 0
) || exit 1

exit 0
