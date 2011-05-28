#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

SRC="src/tcl${TCLVERS}.tar.gz"
SRCURL="http://prdownloads.sourceforge.net/tcl/tcl${TCLVERS}-src.tar.gz"
BUILDDIR="$(pwd)/build/tcl${TCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHSCRIPTDIR="$(pwd)/patchscripts"
PATCHDIR="$(pwd)/patches"
export SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHSCRIPTDIR PATCHDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	use_fossil='0'
	if echo "${TCLVERS}" | grep '^cvs_' >/dev/null; then
		use_fossil='1'

		FOSSILTAG=$(echo "${TCLVERS}" | sed 's/^cvs_//g')
		if [ "${FOSSILTAG}" = "HEAD" ]; then
			FOSSILTAG="trunk"
		fi
	elif echo "${TCLVERS}" | grep '^fossil_' >/dev/null; then
		use_fossil='1'

		FOSSILTAG=$(echo "${TCLVERS}" | sed 's/^fossil_//g')
	fi
	export FOSSILTAG

	if [ "${use_fossil}" = "1" ]; then
		(
			cd src || exit 1

			workdir="tmp-$$${RANDOM}${RANDOM}${RANDOM}"
			rm -rf "${workdir}"

			mkdir "${workdir}" || exit 1
			cd "${workdir}" || exit 1

			# Handle Tcl first, since it will be used to base other packages on
			wget -O "tmp-tcl.tar.gz" "http://core.tcl.tk/tcl/tarball/tcl-fossil.tar.gz?uuid=${FOSSILTAG}" || rm -f 'tmp-tcl.tar.gz'
			gzip -dc 'tmp-tcl.tar.gz' | tar -xf -
			mv "tcl-fossil" "tcl${TCLVERS}"

			# Determine date of this Tcl release and use that date for all other dependent packages
			## Unless the release we are talking about is "trunk", in which case we use that everywhere
			if [ "${FOSSILTAG}" = "trunk" ]; then
				FOSSILDATE="${FOSSILTAG}"
			else
				FOSSILDATE="$(echo 'cd "tcl'"${TCLVERS}"'"; set file [lindex [glob *] 0]; file stat $file finfo; set date $finfo(mtime); set date [expr {$date + 1}]; puts [clock format $date -format {%Y-%m-%dT%H:%M:%S}]' | TZ='UTC' "${TCLSH_NATIVE}")"
			fi

			## If we are unable to determine the modification date, fall-back to the tag and hope for the best
			if [ -z "${FOSSILDATE}" ]; then
				FOSSILDATE="${FOSSILTAG}"
			fi

			# Handle other packages
			wget -O "tmp-itcl.tar.gz" "http://core.tcl.tk/itcl/tarball/itcl-fossil.tar.gz?uuid=${FOSSILDATE}" || rm -f 'tmp-itcl.tar.gz'
			wget -O "tmp-thread.tar.gz" "http://core.tcl.tk/thread/tarball/thread-fossil.tar.gz?uuid=${FOSSILDATE}" || rm -f "tmp-thread.tar.gz"
			wget -O "tmp-tclconfig.tar.gz" "http://core.tcl.tk/tclconfig/tarball/tclconfig-fossil.tar.gz?uuid=${FOSSILDATE}" || rm -f "tmp-tclconfig.tar.gz"

			gzip -dc "tmp-itcl.tar.gz" | tar -xf -
			gzip -dc "tmp-thread.tar.gz" | tar -xf -
			gzip -dc "tmp-tclconfig.tar.gz" | tar -xf -

			mkdir -p "tcl${TCLVERS}/pkgs/" >/dev/null 2>/dev/null
			mv "itcl-fossil" "tcl${TCLVERS}/pkgs/itcl"
			mv "thread-fossil" "tcl${TCLVERS}/pkgs/thread"
			cp -r "tclconfig-fossil" "tcl${TCLVERS}/pkgs/itcl/tclconfig"
			cp -r "tclconfig-fossil" "tcl${TCLVERS}/pkgs/thread/tclconfig"
			mv "tclconfig-fossil" "tcl${TCLVERS}/tclconfig"

			tar -cf - "tcl${TCLVERS}" | gzip -c > "../../${SRC}"
			echo "${FOSSILDATE}" > "../../${SRC}.date"

			cd ..

			rm -rf "${workdir}"
		) || exit 1
	else
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

	cd "${BUILDDIR}" || exit 1

	# Apply patches if needed
	for patch in "${PATCHDIR}/all"/tcl-${TCLVERS}-*.diff "${PATCHDIR}/${TCLVERS}"/tcl-${TCLVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi
                
		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done


	# Apply patch scripts if needed
	for patchscript in "${PATCHSCRIPTDIR}"/*.sh; do
		if [ -f "${patchscript}" ]; then
			echo "Running patch script: ${patchscript}"

			(
				. "${patchscript}"
			)
		fi
	done

	for dir in unix win macosx __fail__; do
		if [ "${dir}" = "__fail__" ]; then
			# If we haven't figured out how to build it, reject.

			exit 1
		fi

		# Remove previous directory's "tclConfig.sh" if found
		rm -f 'tclConfig.sh'

		cd "${BUILDDIR}/${dir}" || exit 1

		echo "Running: ./configure --disable-shared --with-encoding=utf-8 --prefix=\"${INSTDIR}\" ${CONFIGUREEXTRA}"
		./configure --disable-shared --with-encoding=utf-8 --prefix="${INSTDIR}" ${CONFIGUREEXTRA}

		echo "Running: ${MAKE:-make}"
		${MAKE:-make} || continue

		echo "Running: ${MAKE:-make} install"
		${MAKE:-make} install || (
			# Work with Tcl 8.6.x's TCLSH_NATIVE solution for
			# cross-compile installs

			echo "Running: ${MAKE:-make} install TCLSH_NATIVE=\"${TCLSH_NATIVE}\""
			${MAKE:-make} install TCLSH_NATIVE="${TCLSH_NATIVE}"
		) || (
			# Make install can fail if cross-compiling using Tcl 8.5.x
			# because the Makefile calls "$(TCLSH)".  We can't simply
			# redefine TCLSH because it also uses TCLSH as a build target
			sed 's@^$(TCLSH)@blah@' Makefile > Makefile.new
			cat Makefile.new > Makefile
			rm -f Makefile.new

			echo "Running: ${MAKE:-make} install TCLSH=\"../../../../../../../../../../../../../../../../../$(which "${TCLSH_NATIVE}")\""
			${MAKE:-make} install TCLSH="../../../../../../../../../../../../../../../../../$(which "${TCLSH_NATIVE}")"
		) || (
			# Make install can fail if cross-compiling using Tcl 8.5.9
			# because the Makefile calls "${TCL_EXE}".  We can't simply
			# redefine TCL_EXE because it also uses TCL_EXE as a build target
			sed 's@^${TCL_EXE}@blah@' Makefile > Makefile.new
			cat Makefile.new > Makefile
			rm -f Makefile.new

			echo "Running: ${MAKE:-make} install TCL_EXE=\"../../../../../../../../../../../../../../../../../$(which "${TCLSH_NATIVE}")\""
			${MAKE:-make} install TCL_EXE="../../../../../../../../../../../../../../../../../$(which "${TCLSH_NATIVE}")"
		) || exit 1

		mkdir "${OUTDIR}/lib" || exit 1
		cp -r "${INSTDIR}/lib"/* "${OUTDIR}/lib/"
		rm -rf "${OUTDIR}/lib/pkgconfig"
		rm -f "${OUTDIR}"/lib/* >/dev/null 2>/dev/null
		find "${OUTDIR}" -name '*.a' | xargs rm -f >/dev/null 2>/dev/null

		# Clean up packages that are not needed
		if [ -n "${KITCREATOR_MINBUILD}" ]; then
			find "${OUTDIR}" -name "tcltest*" -type d | xargs rm -rf
		fi

		# Clean up encodings
		if [ -n "${KITCREATOR_MINENCODINGS}" ]; then
			KEEPENCODINGS=" ascii.enc cp1252.enc iso8859-1.enc iso8859-15.enc iso8859-2.enc koi8-r.enc macRoman.enc "
			export KEEPENCODINGS
			find "${OUTDIR}/lib" -name 'encoding' -type d | while read encdir; do
				(
					cd "${encdir}" || exit 1

					for file in *; do
						if echo " ${KEEPENCODINGS} " | grep " ${file} " >/dev/null; then
							continue
						fi

						rm -f "${file}"
					done
				)
			done
		fi

		break
	done
) || exit 1

exit 0
