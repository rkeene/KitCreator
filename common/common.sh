#! /usr/bin/env bash

targetInstallEnvironment='kitcreator'
pkgdir="$(pwd)"
internalpkgname="${pkg}"
archivedir="${pkgdir}/src"
buildsrcdir="${pkgdir}/buildsrc"
installdir="${pkgdir}/inst"
runtimedir="${pkgdir}/out"
workdir="${pkgdir}/workdir-$$${RANDOM}${RANDOM}${RANDOM}${RANDOM}.work"

_download="$(which download)"

function clean() {
	rm -rf "${installdir}" "${runtimedir}"
}

function distclean() {
	rm -rf "${archivedir}"
	rm -rf "${pkgdir}"/workdir-*
}

function init() {
	clean || return 1

	TCL_VERSION="unknown"
	if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
		source "${TCLCONFIGDIR}/tclConfig.sh"
	fi
	export TCL_VERSION
}

function predownload() {
	:
}

function download() {
	if [ -d "${buildsrcdir}" ]; then
		return 0
	fi

	if [ -n "${url}" ]; then
		# Determine type of file
		archivetype="$(echo "${url}" | sed 's@\?.*$@@')"
		case "${archivetype}" in
			*.tar.*)
				archivetype="$(echo "${archivetype}" | sed 's@^.*\.tar\.@tar.@')"
				;;
			*)
				archivetype="$(echo "${archivetype}" | sed 's@^.*\.@@')"
				;;
		esac

		pkgarchive="${archivedir}/${pkg}-${version}.${archivetype}"
		mkdir "${archivedir}" >/dev/null 2>/dev/null
	fi

	if [ -n "${url}" -a -n "${pkgarchive}" -a ! -e "${pkgarchive}" ]; then
		"${_download}" "${url}" "${pkgarchive}" "${sha256}" || return 1
	fi

	return 0
}

function postdownload() {
	:
}

function extract() {
	if [ -d "${buildsrcdir}" ]; then
		mkdir "${workdir}" || return 1

		cp -rp "${buildsrcdir}"/* "${workdir}" || return 1

		return 0
	fi

	if [ -n "${pkgarchive}" ]; then
		(
			mkdir "${workdir}" || exit 1

			cd "${workdir}" || exit 1

			case "${pkgarchive}" in
				*.tar.gz|*.tgz)
					gzip -dc "${pkgarchive}" | tar -xf - || exit 1
					;;
				*.tar.bz2|*.tbz|*.tbz2)
					bzip2 -dc "${pkgarchive}" | tar -xf - || exit 1
					;;
				*.tar.xz|*.txz)
					xz -dc "${pkgarchive}" | tar -xf - || exit 1
					;;
				*.zip)
					unzip "${pkgarchive}" || exit 1
					;;
			esac

			shopt -s dotglob
			dir="$(echo ./*)"
			if [ -d "${dir}" ]; then
				mv "${dir}"/* . || exit 1

				rmdir "${dir}" || exit 1
			fi

			exit 0
		) || return 1
	fi

	return 0
}

function apply_patches() {
	:
}

function preconfigure() {
	:
}

function configure() {
	local tryopts tryopt
	local staticpkg staticpkgvar
	local isshared
	local save_cflags
	local base_var kc_var

	staticpkgvar="$(echo "STATIC${internalpkgname}" | dd conv=ucase 2>/dev/null)"
	staticpkg="$(eval "echo \"\$${staticpkgvar}\"")"

	# Set configure options for this sub-project
	for base_var in LDFLAGS CFLAGS CPPFLAGS LIBS; do
		kc_var="$(echo "KC_${internalpkgname}_${base_var}" | dd conv=ucase 2>/dev/null)"
		kc_var_val="$(eval "echo \"\$${kc_var}\"")"

		if [ -n "${kc_var_val}" ]; then
			eval "${base_var}=\"\$${base_var} \$${kc_var}\"; export ${base_var}"
		fi
	done

	# Determine if we should enable shared or not
	if [ "${staticpkg}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${staticpkg}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	save_cflags="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		if [ "${tryopt}" = "__fail__" ]; then
			return 1
		fi

		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static package for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${save_cflags} -fPIC"
		else
			CFLAGS="${save_cflags}"
		fi
		export CFLAGS

		if [ "${isshared}" = '0' ]; then
			sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' configure > configure.new

			pkg_configure_shared_build='0'
		else
			sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' configure > configure.new

			pkg_configure_shared_build='1'
		fi

		cat configure.new > configure
		rm -f configure.new

		./configure $tryopt --prefix="${installdir}" --exec-prefix="${installdir}" --libdir="${installdir}/lib" --with-tcl="${TCLCONFIGDIR}" "${configure_extra[@]}" ${CONFIGUREEXTRA} && break
	done

	return 0
}

function postconfigure() {
	:
}

function prebuild() {
	:
}

function build() {
	${MAKE:-make} tcllibdir="${installdir}/lib" "${make_extra[@]}"
}

function postbuild() {
	:
}

function preinstall() {
	:
}

function install() {
	local installpkgdir
	local pkglibfile

	mkdir -p "${installdir}/lib" || return 1
	${MAKE:-make} tcllibdir="${installdir}/lib" "${make_extra[@]}" install || return 1

	# Create pkgIndex if needed
	installpkgdir="$(echo "${installdir}/lib"/*)"

	if [ -d "${installpkgdir}" ]; then
		if [ ! -e "${installpkgdir}/pkgIndex.tcl" ]; then
			case "${pkg_configure_shared_build}" in
				0)
					cat << _EOF_ > "${installpkgdir}/pkgIndex.tcl"
package ifneeded ${pkg} ${version} [list load {} ${pkg}]
_EOF_
					;;
				1)
					pkglibfile="$(find "${installpkgdir}" -name '*.so' -o -name '*.dylib' -o -name '*.dll' -o -name '*.shlib' | head -n 1 | sed 's@^.*/@@')"
					cat << _EOF_ > "${installpkgdir}/pkgIndex.tcl"
package ifneeded ${pkg} ${version} [list load [file join \$dir ${pkglibfile}]]
_EOF_
					;;
			esac
		fi
	fi
}

function postinstall() {
	:
}

function createruntime() {
	local file

	# Install files needed by installation
	mkdir -p "${runtimedir}" || return 1
	cp -r "${installdir}/lib" "${runtimedir}" || return 1

	find "${runtimedir}" -name '*.a' -type f | while IFS='' read -r file; do
		rm -f "${file}"
	done

	# Ensure that some files were installed
	if ! find "${runtimedir}" -type f 2>/dev/null | grep '^' >/dev/null; then
		return 1
	fi

	return 0
}

function die() {
	local msg

	msg="$1"

	echo "$msg" >&2

	exit 1
}
