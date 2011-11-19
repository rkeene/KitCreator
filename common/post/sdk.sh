#! /bin/bash

if [ -z "${TCLVERS}" ]; then
	echo 'This script is not meant to be run directly.' >&2

	exit 1
fi

if [ "${KITTARGET}" != "kitdll" ]; then
	exit 0
fi

rm -rf '__tmp__'
mkdir '__tmp__'
mkdir '__tmp__/include'
mkdir '__tmp__/lib'
mkdir '__tmp__/doc'

cp 'tcl/inst/lib/tclConfig.sh' '__tmp__/lib/'
cp -rp 'tcl/inst/include'/* '__tmp__/include/'
cp 'tcl/inst/lib'/libtclstub* '__tmp__/lib/'

if [ -f 'tk/inst/lib/tkConfig.sh' ]; then
	cp 'tk/inst/lib/tkConfig.sh' '__tmp__/lib/'
	cp -rp 'tk/inst/include'/* '__tmp__/include/'
	cp 'tk/inst/lib'/libtkstub* '__tmp__/lib/'
fi

cp 'kitsh/build'/kitsh-*/libtclkit* '__tmp__/lib/'

for dir in */; do
	if [ ! -d "${dir}/build" ]; then
		continue
	fi

	project="$(basename "${dir}")"
	projdir="$(cd "${dir}/build"/* >/dev/null 2>/dev/null || exit; /bin/pwd)"
	docdir="__tmp__/doc/${project}"

	if [ -z "${projdir}" -o ! -d "${projdir}" ]; then
		continue
	fi

	mkdir -p "${docdir}"

	case "${project}" in
		itcl|tcl|tk)
			if [ -f "${projdir}/doc/license.terms" ]; then
				cp "${projdir}/doc/license.terms" "${docdir}/"
			elif [ -f "${projdir}/license.terms" ]; then
				cp "${projdir}/license.terms" "${docdir}/"
			fi
			;;
		tclvfs|kitsh|mk4tcl|thread)
			cp "${projdir}/license.terms" "${docdir}/"
			;;
		zlib)
			cp "${projdir}/README" "${docdir}/"
			;;
		*)
			cp "${projdir}/README" "${projdir}/LICENSE" "${projdir}/doc/README" "${projdir}/doc/LICENSE" "${projdir}/license.terms" "${projdir}/doc/license.terms" "${docdir}/" >/dev/null 2>/dev/null
			;;
	esac
done

(
	cd '__tmp__/lib' || exit 1

	for kitlibfile in libtclkit*.dll libtclkit*; do
		if [ ! -f "${kitlibfile}" ]; then
			continue
		fi

		if echo "${kitlibfile}" | grep '\.tar\.gz' >/dev/null; then
			continue
		fi

		break
	done
	kitlinker="$(echo "${kitlibfile}" | sed 's@^lib@-l@;s@\.[^\.]*$@@')"

	sed 's|'"$(dirname "$(dirname "$(pwd)")")"'/tcl/inst|${TCLKIT_SDK_DIR}|g;s|^TCL_SHARED_BUILD=.*$|TCL_SHARED_BUILD=1|;s|^TCL_LIB_FILE=.*$|TCL_LIB_FILE='"${kitlibfile}"'|;s|-ltcl[^s][a-zA-Z0-9\.]*|'"${kitlinker}"'|' 'tclConfig.sh' > 'tclConfig.sh.new'
	(
		cat << _EOF_
if [ -z "\${TCLKIT_SDK_DIR}" ]; then
	TCLKIT_SDK_DIR="./libtclkit-sdk-${TCLVERS}"
fi

_EOF_
		cat 'tclConfig.sh.new'
	) > 'tclConfig.sh'
	rm -f 'tclConfig.sh.new'

	if [ -f 'tkConfig.sh' ]; then
		sed 's|'"$(dirname "$(dirname "$(pwd)")")"'/tk/inst|${TCLKIT_SDK_DIR}|g;s|^TK_SHARED_BUILD=.*$|TK_SHARED_BUILD=1|;s|^TK_LIB_FILE=.*$|TK_LIB_FILE='"${kitlibfile}"'|;s|-ltk[^s][a-zA-Z0-9\.]*|'"${kitlinker}"'|' 'tkConfig.sh' > 'tkConfig.sh.new'
		(
			cat << _EOF_
if [ -z "\${TCLKIT_SDK_DIR}" ]; then
	TCLKIT_SDK_DIR="./libtclkit-sdk-${TCLVERS}"
fi

_EOF_
			cat 'tkConfig.sh.new'
		) > 'tkConfig.sh'
		rm -f 'tkConfig.sh.new'
	fi
)

(
	cd '__tmp__' || exit 1

	mkdir "libtclkit-sdk-${TCLVERS}"

	mv 'lib' 'include' 'doc' "libtclkit-sdk-${TCLVERS}/"

	tar -cf - "libtclkit-sdk-${TCLVERS}" | gzip -9c > "../libtclkit-sdk-${TCLVERS}.tar.gz"
)

rm -rf '__tmp__'

exit 0
