#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TLSVERS="1.6.7"
SRC="src/tls-${TLSVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tls/files/tls/${TLSVERS}/tls${TLSVERS}-src.tar.gz"
SRCHASH='5119de3e5470359b97a8a00d861c9c48433571ee0167af0a952de66c99d3a3b8'
BUILDDIR="$(pwd)/build/tls${TLSVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TLSVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${LDFLAGS} ${KC_TLS_LDFLAGS}"
CFLAGS="${CFLAGS} ${KC_TLS_CFLAGS}"
CPPFLAGS="${CPPFLAGS} ${KC_TLS_CPPFLAGS}"
LIBS="${LIBS} ${KC_TLS_LIBS}"
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

function buildSSLLibrary() {
	local version url hash
	local archive

	version='2.4.1'
	url="http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${version}.tar.gz"
	hash='121922b13169cd47a85e3e77f0bc129f8d04247193b42491cb1fab9074e80477'

	archive="src/libressl-${version}.tar.gz"

	echo " *** Building LibreSSL v${version}" >&2

	if [ ! -e "../${archive}" ]; then
		download "${url}" "../${archive}" "${hash}" || return 1
	fi

	(
		rm -rf libressl-*

		gzip -dc "../${archive}" | tar -xf - || exit 1

		cd "libressl-${version}" || exit 1

		echo "Running: ./configure ${CONFIGUREEXTRA} --disable-shared --enable-static --prefix=\"$(pwd)/INST\""
		./configure ${CONFIGUREEXTRA} --disable-shared --enable-static --prefix="$(pwd)/INST" || exit 1

		echo "Running: ${MAKE:-make} V=1"
		${MAKE:-make} V=1 || exit 1

		echo "Running: ${MAKE:-make} V=1 install" 
		${MAKE:-make} V=1 install || exit 1
	) || return 1

	SSLDIR="$(pwd)/libressl-${version}/INST"
	addlibs="$(PKG_CONFIG_PATH="$(pwd)/libressl-${version}/INST/lib/pkgconfig" "${PKG_CONFIG:-pkg-config}" libssl libcrypto --libs --static)"
}

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
	else    
		cp -rp ../buildsrc/* './'
	fi

	# Determine SSL directory
	if [ -z "${CPP}" ]; then
		CPP="${CC:-cc} -E"
	fi

	if [ -n "${KC_TLS_SSLDIR}" ]; then
		SSLDIR="${KC_TLS_SSLDIR}"
	else
		SSLDIR=''

		if [ -z "${KC_TLS_BUILDSSL}" ]; then
			SSLDIR="$(echo '#include <openssl/ssl.h>' 2>/dev/null | ${CPP} - 2> /dev/null | awk '/# 1 "\/.*\/ssl\.h/{ print $3; exit }' | sed 's@^"@@;s@"$@@;s@/include/openssl/ssl\.h$@@')"
		fi

		if [ -z "${SSLDIR}" ]; then
			buildSSLLibrary || SSLDIR=''
		fi

		if [ -z "${SSLDIR}" ]; then
			echo "Unable to find OpenSSL, aborting." >&2

			exit 1
		fi
	fi

	# Apply required patches
	cd "${BUILDDIR}" || exit 1
	for patch in "${PATCHDIR}/all"/tls-${TLSVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tls-${TLSVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done

	cd "${BUILDDIR}" || exit 1

	# Try to build as a shared object if requested
	if [ "${STATICTLS}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTLS}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	# Disable SSLv2, newer SSL libraries drop support for it entirely
	CFLAGS="${CFLAGS} -DNO_SSL2=1"

	# Disable SSLv3, newer SSL libraries drop support for it entirely
	CFLAGS="${CFLAGS} -DNO_SSL3=1"

	SAVE_CFLAGS="${CFLAGS}"
	SAVE_LIBS="${LIBS}"
	for tryopt in $tryopts __fail__; do
		CFLAGS="${SAVE_CFLAGS}"
		LIBS="${SAVE_LIBS}"
		export CFLAGS LIBS

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

		# If building a shared TLS, add the LINKADD libraries here
		if [ "${isshared}" = '1' ]; then
			LIBS="${LIBS} ${KC_TLS_LINKADD}"
		fi

		# If build a static TLS for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${CFLAGS} -fPIC"
		fi

		if [ "${isshared}" = '0' ]; then
			sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' configure > configure.new
		else
			sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' configure > configure.new
		fi
		cat configure.new > configure
		rm -f configure.new

		(
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" --with-ssl-dir=\"${SSLDIR}\" ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" --with-ssl-dir="${SSLDIR}" ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" AR=\"${AR:-ar}\" RANLIB=\"${RANLIB:-ranlib}\""
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" AR="${AR:-ar}" RANLIB="${RANLIB:-ranlib}" || exit 1

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" AR=\"${AR:-ar}\" RANLIB=\"${RANLIB:-ranlib}\" install"
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" AR="${AR:-ar}" RANLIB="${RANLIB:-ranlib}" install || exit 1
		) || continue

		# Determine SSL library directory
		SSL_LIB_DIR="$(${MAKE:-make} --print-data-base | awk '/^SSL_LIB_DIR = /{ print }' | sed 's@^SSL_LIB_DIR = *@@')"

		echo "SSL_LIB_DIR = ${SSL_LIB_DIR}"

		break
	done

	# Create pkgIndex if needed
	if [ ! -e "${INSTDIR}/lib/tls${TLSVERS}/pkgIndex.tcl" ]; then
		cat << _EOF_ > "${INSTDIR}/lib/tls${TLSVERS}/pkgIndex.tcl"
package ifneeded tls ${TLSVERS} \
    "[list source [file join \$dir tls.tcl]] ; \
     [list load {} tls]"
_EOF_
	fi

	# Determine name of static object
	LINKADDFILE="$(find "${INSTDIR}" -name '*.a' | head -n 1)"
	if [ -n "${LINKADDFILE}" ]; then
		LINKADDFILE="${LINKADDFILE}.linkadd"

		## XXX: TODO: Determine what we actually need to link against
		if [ -z "${addlibs}" ]; then
			if [ "${KC_TLS_LINKSSLSTATIC}" = '1' ]; then
				addlibs="$("${PKG_CONFIG:-pkg-config}" libssl libcrypto --libs --static)"
			else
				addlibs="$("${PKG_CONFIG:-pkg-config}" libssl libcrypto --libs)"
			fi
		fi

		if [ -z "${addlibs}" ]; then
			addlibs="-L${SSL_LIB_DIR:-/lib} -lssl -lcrypto"
			addlibs_staticOnly=""
		fi

		addlibs="${addlibs} ${KC_TLS_LINKADD}"

		if [ "${KC_TLS_LINKSSLSTATIC}" = '1' ]; then
			echo "-Wl,-Bstatic ${addlibs} ${addlibs_staticOnly} -Wl,-Bdynamic"
		else
			echo "${addlibs}"
		fi > "${LINKADDFILE}"
	fi

	# Install files needed by installation
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | xargs -n 1 rm -f --

	exit 0
) || exit 1

exit 0
