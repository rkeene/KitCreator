#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TCC4TCLVERS="0.13"
SRC="src/tcc4tcl-${TCC4TCLVERS}.tar.gz"
SRCURL="http://rkeene.org/devel/tcc4tcl/tcc4tcl-${TCC4TCLVERS}.tar.gz"
BUILDDIR="$(pwd)/build/tcc4tcl-${TCC4TCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TCC4TCLVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_TCC4TCL_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_TCC4TCL_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_TCC4TCL_CPPFLAGS}"
LIBS="${LIBS} ${KC_TCC4TCL_LIBS}"
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

	for patch in "${PATCHDIR}/all"/tcc4tcl-${TCC4TCLVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tcc4tcl-${TCC4TCLVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done

	# Try to build as a shared object if requested
	if [ "${STATICTCC4TCL}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTCC4TCL}" = "-1" ]; then
		# Require shared object if requested
		tryopts="--enable-shared"
	else
		# Default to building statically
		tryopts="--disable-shared"
	fi

	if echo " ${CONFIGUREEXTRA} " | grep ' --disable-load ' >/dev/null; then
		dlopen_flag="--with-dlopen"
	else
		dlopen_flag="--without-dlopen"
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

		# If build a static tcc4tcl for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${SAVE_CFLAGS} -fPIC"
		else
			CFLAGS="${SAVE_CFLAGS}"
		fi

		(
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${dlopen_flag} ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${dlopen_flag} ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make}"
			${MAKE:-make} || exit 1

			echo "Running: ${MAKE:-make} install"
			${MAKE:-make} install || exit 1
		) || continue

		break
	done

	# Create VFS-insert
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | grep -v '/libtcc1\.a$' | xargs rm -f

	# Tell Kitsh not to try to link against "libtcc1.a"
	echo "/libtcc1\.a" > "${INSTDIR}/kitcreator-nolibs"

	exit 0
) || exit 1

exit 0
