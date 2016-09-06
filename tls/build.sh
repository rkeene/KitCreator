#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.6.7"
url="http://sourceforge.net/projects/tls/files/tls/${TLSVERS}/tls${TLSVERS}-src.tar.gz"
sha256='5119de3e5470359b97a8a00d861c9c48433571ee0167af0a952de66c99d3a3b8'

function buildSSLLibrary() {
	local version url hash
	local archive

	version='2.4.2'
	url="http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${version}.tar.gz"
	hash='5f87d778e5d62822d60e38fa9621c1c5648fc559d198ba314bd9d89cbf67d9e3'

	archive="src/libressl-${version}.tar.gz"

	echo " *** Building LibreSSL v${version}" >&2

	if [ ! -e "${pkgdir}/${archive}" ]; then
		"${_download}" "${url}" "${pkgdir}/${archive}" "${hash}" || return 1
	fi

	(
		rm -rf libressl-*

		gzip -dc "${pkgdir}/${archive}" | tar -xf - || exit 1

		cd "libressl-${version}" || exit 1

		# This defeats hardening attempts that break on various platforms
		CFLAGS=' -g -O0 '
		export CFLAGS

		./configure ${CONFIGUREEXTRA} --disable-shared --enable-static --prefix="$(pwd)/INST" || exit 1

		# Disable building the apps -- they do not get used
		rm -rf apps
		mkdir apps
		cat << \_EOF_ > apps/Makefile
%:
	@echo Nothing to do
_EOF_

		${MAKE:-make} V=1 || exit 1

		${MAKE:-make} V=1 install || exit 1
	) || return 1

	SSLDIR="$(pwd)/libressl-${version}/INST"
	addlibs_LOCALSSL="$(PKG_CONFIG_PATH="${SSLDIR}/lib/pkgconfig" "${PKG_CONFIG:-pkg-config}" libssl libcrypto --libs --static)"
}

function preconfigure() {
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

			return 1
		fi
	fi

	# Add SSL library to configure options
	configure_extra=(--with-ssl-dir="${SSLDIR}")

	# Disable SSLv2, newer SSL libraries drop support for it entirely
	CFLAGS="${CFLAGS} -DNO_SSL2=1"

	# Disable SSLv3, newer SSL libraries drop support for it entirely
	CFLAGS="${CFLAGS} -DNO_SSL3=1"
	export CFLAGS
}

function postconfigure() {
	local linkaddfile
	local addlibs

	# Determine SSL library directory
	SSL_LIB_DIR="$(${MAKE:-make} --print-data-base | awk '/^SSL_LIB_DIR = /{ print }' | sed 's@^SSL_LIB_DIR = *@@')"

	echo "SSL_LIB_DIR = ${SSL_LIB_DIR}"
}

function postinstall() {
	# Create pkgIndex if needed
	if [ ! -e "${installdir}/lib/tls${version}/pkgIndex.tcl" ]; then
		cat << _EOF_ > "${installdir}/lib/tls${version}/pkgIndex.tcl"
package ifneeded tls ${version} \
    "[list source [file join \$dir tls.tcl]] ; \
     [list load {} tls]"
_EOF_
	fi

	# Determine name of static object
	linkaddfile="$(find "${installdir}" -name '*.a' | head -n 1)"
	if [ -n "${linkaddfile}" ]; then
		linkaddfile="${linkaddfile}.linkadd"

		if [ -n "${addlibs_LOCALSSL}" ]; then
			addlibs="${addlibs_LOCALSSL}"
		fi

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
		fi > "${linkaddfile}"
	fi
}
