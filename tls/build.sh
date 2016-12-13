#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.7.8"
url="http://tcltls.rkeene.org/uv/tcltls-${version}.tar.gz"
sha256='30ee49330db795f86bc850487421ea923fba7d95d4758b2a61eef3baf0fe0f9e'
configure_extra=('--enable-deterministic')

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

	PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${SSLDIR}/lib/pkgconfig"
	export PKG_CONFIG_PATH

	SSLDIR="$(pwd)/libressl-${version}/INST"

	return 0
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
	configure_extra=("${configure_extra[@]}" --with-openssl-dir="${SSLDIR}")
}

function postinstall() {
	for file in *.linkadd; do
		if [ ! -e "${file}" ]; then
			continue
		fi

		cp "${file}" "${installdir}/lib"/*/
	done
}
