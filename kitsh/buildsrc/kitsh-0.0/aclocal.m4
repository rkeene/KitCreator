AC_DEFUN(DC_DO_TCL, [
	AC_MSG_CHECKING([path to tcl])
	AC_ARG_WITH(tcl, AC_HELP_STRING([--with-tcl], [directory containing tcl configuration (tclConfig.sh)]), [], [
		with_tcl="auto"
	])

	if test "${with_tcl}" = "auto"; then
		for dir in `echo "${PATH}" | sed 's@:@ @g'`; do
			if test -f "${dir}/tclConfig.sh"; then
				tclconfigshdir="${dir}"
				tclconfigsh="${tclconfigshdir}/tclConfig.sh"
				break
			fi
			if test -f "${dir}/../lib/tclConfig.sh"; then
				tclconfigshdir="${dir}/../lib"
				tclconfigsh="${tclconfigshdir}/tclConfig.sh"
				break
			fi
			if test -f "${dir}/../lib64/tclConfig.sh"; then
				tclconfigshdir="${dir}/../lib64"
				tclconfigsh="${tclconfigshdir}/tclConfig.sh"
				break
			fi
		done

		if test -z "${tclconfigsh}"; then
			AC_MSG_ERROR([Unable to find tclConfig.sh])
		fi
	else
		tclconfigshdir="${with_tcl}"
		tclconfigsh="${tclconfigshdir}/tclConfig.sh"
	fi

	if test -f "${tclconfigsh}"; then
		. "${tclconfigsh}"

		CFLAGS="${CFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic -I${tclconfigshdir}"
		CPPFLAGS="${CPPFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic -I${tclconfigshdir}"
		LDFLAGS="${LDFLAGS}"
		LIBS="${LIBS} ${TCL_LIBS}"
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LDFLAGS)
	AC_SUBST(LIBS)

	AC_MSG_RESULT([$tclconfigsh])
])

AC_DEFUN(DC_DO_TK, [
	AC_MSG_CHECKING([path to tk])
	AC_ARG_WITH(tk, AC_HELP_STRING([--with-tk], [directory containing tk configuration (tkConfig.sh)]), [], [
		with_tk="auto"
	])

	if test "${with_tk}" = "auto"; then
		for dir in ../../../tk/build/tk*/*/ `echo "${PATH}" | sed 's@:@ @g'`; do
			if test -f "${dir}/tkConfig.sh"; then
				tkconfigshdir="${dir}"
				tkconfigsh="${tkconfigshdir}/tkConfig.sh"
				break
			fi
			if test -f "${dir}/../lib/tkConfig.sh"; then
				tkconfigshdir="${dir}/../lib"
				tkconfigsh="${tkconfigshdir}/tkConfig.sh"
				break
			fi
			if test -f "${dir}/../lib64/tkConfig.sh"; then
				tkconfigshdir="${dir}/../lib64"
				tkconfigsh="${tkconfigshdir}/tkConfig.sh"
				break
			fi
		done

		if test -z "${tkconfigsh}"; then
			AC_MSG_ERROR([Unable to find tkConfig.sh])
		fi
	else
		tkconfigshdir="${with_tk}"
		tkconfigsh="${tkconfigshdir}/tkConfig.sh"
	fi

	if test -f "${tkconfigsh}"; then
		. "${tkconfigsh}"

		CFLAGS="${CFLAGS} ${TK_INCLUDE_SPEC} -I${TK_SRC_DIR}/generic -I${tkconfigshdir}"
		CPPFLAGS="${CPPFLAGS} ${TK_INCLUDE_SPEC} -I${TK_SRC_DIR}/generic -I${tkconfigshdir}"
		LDFLAGS="${LDFLAGS}"
		LIBS="${LIBS} ${TK_LIBS}"
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LDFLAGS)
	AC_SUBST(LIBS)

	AC_MSG_RESULT([$tkconfigsh])
])

AC_DEFUN(DC_DO_STATIC_LINK_LIBCXX, [
	AC_MSG_CHECKING([for how to statically link to libstdc++])

	SAVELIBS="${LIBS}"
	staticlibcxx=""
	dnl HP/UX uses -Wl,-a,archive -lstdc++ -Wl,-a,shared_archive
	dnl Linux and Solaris us -Wl,-Bstatic ... -Wl,-Bdynamic
	dnl
	dnl Sun Studio uses -lCstd -lCrun, most platforms use -lstdc++
	for trylink in "-Wl,-a,archive -lstdc++ -Wl,-a,shared_archive" "-Wl,-Bstatic -lCstd -lCrun -Wl,-Bdynamic" "-Wl,-Bstatic -lstdc++ -Wl,-Bdynamic" "-lCstd -lCrun" "-lstdc++"; do
		LIBS="${SAVELIBS} ${trylink}"

		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []), [
			staticlibcxx="${trylink}"

			break
		])
	done
	LIBS="${SAVELIBS} ${staticlibcxx}"

	AC_MSG_RESULT([${staticlibcxx}])

	AC_SUBST(LIBS)
])

AC_DEFUN(DC_FIND_TCLKIT_LIBS, [
	DC_SETUP_TCL_PLAT_DEFS

	for proj in mk4tcl tcl tclvfs tk; do
		AC_MSG_CHECKING([for libraries required for ${proj}])

		libdir="../../../${proj}/inst"
		libfiles="`find "${libdir}" -name '*.a' | tr "\n" ' '`"
		libfilesnostub="`find "${libdir}" -name '*.a' | grep -v 'stub' | tr "\n" ' '`"

		ARCHS="${ARCHS} ${libfiles}"

		AC_MSG_RESULT([${libfiles}])

		if test "${libfilesnostub}" != ""; then
			if test "${proj}" = "mk4tcl"; then
				AC_DEFINE(KIT_INCLUDES_MK4TCL, [1], [Specify this if you link against mkt4tcl])
				DC_DO_STATIC_LINK_LIBCXX
			fi
			if test "${proj}" = "tk"; then
				DC_DO_TK
				AC_DEFINE(KIT_INCLUDES_TK, [1], [Specify this if we link statically to Tk])

				if test "$host_os" = "mingw32msvc"; then
					AC_DEFINE(KITSH_NEED_WINMAIN, [1], [Define if you need WinMain (Windows)])
					CFLAGS="${CFLAGS} -mwindows"
				fi
			fi
		fi
	done

	AC_SUBST(ARCHS)
])

AC_DEFUN(DC_SETUP_TCL_PLAT_DEFS, [
	AC_CANONICAL_HOST
  
	AC_MSG_CHECKING(host operating system)
	AC_MSG_RESULT($host_os)
  
	case $host_os in
		mingw32msvc*)
			CFLAGS="${CFLAGS} -mno-cygwin -mms-bitfields"

			dnl If we are building for Win32, we need to define "BUILD_tcl" so that
			dnl TCL_STORAGE_CLASS gets defined as DLLEXPORT, to make static linking
			dnl work
			AC_DEFINE(BUILD_tcl, [1], [Define if you need to pretend to be building Tcl (Windows)])
			AC_DEFINE(BUILD_tk, [1], [Define if you need to pretend to be building Tk (Windows)])
			;;
		cygwin*)
			CFLAGS="${CFLAGS} -mms-bitfields"
			;;
	esac
])

AC_DEFUN(DC_STATIC_LIBGCC, [
	AC_MSG_CHECKING([how to link statically against libgcc])

	SAVELDFLAGS="${LDFLAGS}"
	staticlibgcc=""
	for trylink in "-static-libgcc"; do
		LDFLAGS="${SAVELDFLAGS} ${trylink}"
		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []), [
			staticlibgcc="${trylink}"

			break
		])
	done
	if test -n "${staticlibgcc}"; then
		LDFLAGS="${SAVELDFLAGS} ${staticlibgcc}"
		AC_MSG_RESULT([${staticlibgcc}])
	else
		LDFLAGS="${SAVELDFLAGS}"
		AC_MSG_RESULT([not needed])
	fi

])
