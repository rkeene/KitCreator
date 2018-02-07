#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.7.16"
url="http://tcltls.rkeene.org/uv/tcltls-${version}.tar.gz"
sha256='6845000732bedf764e78c234cee646f95bb68df34e590c39434ab8edd6f5b9af'
configure_extra=('--enable-deterministic')

function buildSSLLibrary() {
	local version url hash
	local archive

	version='2.6.4'
	url="http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${version}.tar.gz"
	hash='638a20c2f9e99ee283a841cd787ab4d846d1880e180c4e96904fc327d419d11f'

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

		./configure ${CONFIGUREEXTRA} --with-pic --disable-shared --enable-static --prefix="$(pwd)/INST" || exit 1

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

	# We always statically link
	KC_TLS_LINKSSLSTATIC='1'

	SSLPKGCONFIGDIR="$(pwd)/libressl-${version}/INST/lib/pkgconfig"

	return 0
}

function preconfigure() {
	# Determine SSL directory
	if [ -z "${CPP}" ]; then
		CPP="${CC:-cc} -E"
	fi

	SSLPKGCONFIGDIR=''
	SSLDIR=''

	if [ -n "${KC_TLS_SSLDIR}" ]; then
		case "${KC_TLS_SSLDIR}" in
			*/pkgconfig|*/pkgconfig/)
				SSLPKGCONFIGDIR="${KC_TLS_SSLDIR}"
				;;
			*)
				SSLDIR="${KC_TLS_SSLDIR}"
				;;
		esac
	else
		SSLGUESS='0'
		if [ -z "${KC_TLS_BUILDSSL}" ]; then
			if ! "${PKG_CONFIG:-pkg-config}" --exists openssl >/dev/null 2>/dev/null; then
				SSLDIR="$(echo '#include <openssl/ssl.h>' 2>/dev/null | ${CPP} - 2> /dev/null | awk '/# 1 "\/.*\/ssl\.h/{ print $3; exit }' | sed 's@^"@@;s@"$@@;s@/include/openssl/ssl\.h$@@')"
			else
				SSLGUESS='1'
			fi
		fi

		if [ -z "${SSLDIR}" -a "${SSLGUESS}" = '0' ]; then
			buildSSLLibrary || SSLPKGCONFIGDIR=''
		fi

		if [ -z "${SSLPKGCONFIGDIR}" -a -z "${SSLDIR}" -a "${SSLGUESS}" = '0' ]; then
			echo "Unable to find OpenSSL, aborting." >&2

			return 1
		fi
	fi

	# Add SSL library to configure options
	if [ -n "${SSLPKGCONFIGDIR}" ]; then
		configure_extra=("${configure_extra[@]}" --with-openssl-pkgconfig="${SSLPKGCONFIGDIR}")
	elif [ -n "${SSLDIR}" ]; then
		configure_extra=("${configure_extra[@]}" --with-openssl-dir="${SSLDIR}")
	fi

	# If we are statically linking to libssl, let tcltls know so it asks for the right
	# packages
	if [ "${KC_TLS_LINKSSLSTATIC}" = '1' ]; then
		configure_extra=("${configure_extra[@]}" --enable-static-ssl)
	fi
}

function postinstall() {
	for file in *.linkadd; do
		if [ ! -e "${file}" ]; then
			continue
		fi

		cp "${file}" "${installdir}/lib"/*/
	done
}
