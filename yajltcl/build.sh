#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="1.5"
url="https://github.com/flightaware/yajl-tcl/archive/v${version}.tar.gz"
sha256='-'

function buildYAJL() {
	local version url hash
	local archive yajlbuilddir

	version='2.1.0'
	url="http://github.com/lloyd/yajl/tarball/${version}"
	hash='-'

	yajlbuilddir="$(pwd)/lloyd-yajl-66cb08c"
	archive="${pkgdir}/src/yajl-${version}.tar.gz"

	echo " *** Building YAJL v${version}" >&2

	if [ ! -e "${pkgdir}/${archive}" ]; then
		"${_download}" "${url}" "${archive}" "${hash}" || return 1
	fi

	(
		gzip -dc "${archive}" | tar -xf - || exit 1
		cd "${yajlbuilddir}" || exit 1

		./configure -p "$(pwd)/INST" || exit 1

		${MAKE:-make} || exit 1

		${MAKE:-make} install || exit 1

		rm -f INST/lib/*.so*
		mv INST/lib/libyajl_s.a INST/lib/libyajl.a || exit 1
	) || return 1

	# Include YAJL's build in our pkg-config path
	PKG_CONFIG_PATH="${yajlbuilddir}/INST/share/pkgconfig"
	YAJL_CFLAGS="-I${yajlbuilddir}/INST/include -I${YAJLBUILDDIR}/INST/include/yajl"
	export PKG_CONFIG_PATH YAJL_CFLAGS
}

function preconfigure() {
	# Build YAJL
	buildYAJL || return 1

	# YAJLTCL releases are incomplete -- they lack a configure script
	autoconf || exit 1
}

function postinstall() {
	local file dir

	find "${installdir}" -type f -name '*.a' | head -n 1 | sed 's@/[^/]*$@@' | while IFS='' read -r dir; do
		find "${workdir}" -type f -name 'libyajl.a' | while IFS='' read -r file; do
			cp "${file}" "${dir}/zz-$(basename "${file}")" || return 1
		done
	done
}
