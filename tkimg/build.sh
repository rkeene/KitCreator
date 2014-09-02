#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TKIMGVERS="1.4.2"
TKIMGVERS_SHORT="$(echo "${TKIMGVERS}" | cut -f 1-2 -d '.')"
SRC="src/tkimg-${TKIMGVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tkimg/files/tkimg/${TKIMGVERS_SHORT}/tkimg${TKIMGVERS}.tar.gz/download"
BUILDDIR="$(pwd)/build/tkimg${TKIMGVERS_SHORT}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
TKCONFIGDIR="$(find ../tk/build -name tkConfig.sh 2>/dev/null | sed 's@/tkConfig\.sh$@@')"
TKCONFIGDIR="$(cd "${TKCONFIGDIR}" 2>/dev/null && pwd)"
export TKIMGVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

if [ -z "${TKCONFIGDIR}" ]; then
	echo "Unable to find Tk, aborting." >&2

	exit 1
fi


# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_TKIMG_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_TKIMG_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_TKIMG_CPPFLAGS}"
LIBS="${LIBS} ${KC_TKIMG_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

TCL_VERSION="unknown"
if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
        source "${TCLCONFIGDIR}/tclConfig.sh"
fi
export TCL_VERSION

# Source Tk config so we know how Tk is configured
source "${TKCONFIGDIR}/tkConfig.sh"

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

	# Apply required patches
	cd "${BUILDDIR}" || exit 1

	for patch in "${PATCHDIR}/all"/tkimg-${TKIMGVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tkimg-${TKIMGVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done

	# Try to build as a shared object if requested
	if [ "${STATICTKIMG}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTKIMG}" = "-1" ]; then
		# Require shared object if requested
		tryopts="--enable-shared"
	else
		# Default to building statically
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

		# If build a static tkimg for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${SAVE_CFLAGS} -fPIC"
		else
			CFLAGS="${SAVE_CFLAGS}"
		fi

		find . -name configure | while IFS='' read -r configure; do
			if [ "${isshared}" = '0' ]; then
				sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' "${configure}" > "${configure}.new"
			else
				sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' "${configure}" > "${configure}.new"
			fi
			cat "${configure}.new" > "${configure}"
			rm -f "${configure}.new"

			if [ "${TK_SHARED_BUILD}" = '1' ]; then
				sed 's@XXX_TK_STUBS@USE_TK_STUBS@g' "${configure}" > "${configure}.new"
			else
				sed 's@USE_TK_STUBS@XXX_TK_STUBS@g' "${configure}" > "${configure}.new"
			fi
			cat "${configure}.new" > "${configure}"
			rm -f "${configure}.new"
		done

		(
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" --with-tk=\"${TKCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" --with-tk="${TKCONFIGDIR}" ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make}"
			${MAKE:-make} || exit 1

			echo "Running: ${MAKE:-make} install"
			${MAKE:-make} install || exit 1
		) || continue

		break
	done

	# Create VFS-insert
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | xargs rm -f

	exit 0
) || exit 1

exit 0
