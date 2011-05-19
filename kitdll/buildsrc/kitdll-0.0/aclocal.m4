dnl Usage:
dnl    DC_TEST_SHOBJFLAGS(shobjflags, shobjldflags, action-if-not-found)
dnl
AC_DEFUN(DC_TEST_SHOBJFLAGS, [
  AC_SUBST(SHOBJFLAGS)
  AC_SUBST(SHOBJLDFLAGS)

  OLD_LDFLAGS="$LDFLAGS"
  SHOBJFLAGS=""

  LDFLAGS="$OLD_LDFLAGS $1 $2"

  AC_TRY_LINK([#include <stdio.h>
int unrestst(void);], [ printf("okay\n"); unrestst(); return(0); ], [ SHOBJFLAGS="$1"; SHOBJLDFLAGS="$2" ], [
  LDFLAGS="$OLD_LDFLAGS"
  $3
])

  LDFLAGS="$OLD_LDFLAGS"
])

AC_DEFUN(DC_GET_SHOBJFLAGS, [
  AC_SUBST(SHOBJFLAGS)
  AC_SUBST(SHOBJLDFLAGS)

  AC_MSG_CHECKING(how to create shared objects)

  if test -z "$SHOBJFLAGS" -a -z "$SHOBJLDFLAGS"; then
    DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -rdynamic], [
      DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared], [
        DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -rdynamic -mimpure-text], [
          DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -mimpure-text], [
            DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -rdynamic -Wl,-G,-z,textoff], [
              DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -Wl,-G,-z,textoff], [
                DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-shared -dynamiclib -flat_namespace -undefined suppress -bind_at_load], [
                  DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-dynamiclib -flat_namespace -undefined suppress -bind_at_load], [
                    DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-Wl,-dynamiclib -Wl,-flat_namespace -Wl,-undefined,suppress -Wl,-bind_at_load], [
                      DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-dynamiclib -flat_namespace -undefined suppress], [
                        DC_TEST_SHOBJFLAGS([-fPIC -DPIC], [-dynamiclib], [
                          AC_MSG_RESULT(cant)
                          AC_MSG_ERROR([We are unable to make shared objects.])
                        ])
                      ])
                    ])
                  ])
                ])
              ])
            ])
          ])
        ])
      ])
    ])
  fi

  AC_MSG_RESULT($SHOBJLDFLAGS $SHOBJFLAGS)
])

AC_DEFUN(DC_CHK_OS_INFO, [
	AC_CANONICAL_HOST
	AC_SUBST(SHOBJEXT)
	AC_SUBST(AREXT)
        AC_SUBST(SHOBJFLAGS)
        AC_SUBST(SHOBJLDFLAGS)

        AC_MSG_CHECKING(host operating system)
        AC_MSG_RESULT($host_os)

	SHOBJEXT="so"
	AREXT="a"

        case $host_os in
                darwin*)
			SHOBJEXT="dylib"
                        ;;
		hpux*)
			SHOBJEXT="sl"
			;;
		mingw*)
			SHOBJEXT="dll"
			SHOBJFLAGS="-mno-cygwin -mms-bitfields -DPIC"
			SHOBJLDFLAGS='-shared -Wl,--dll -Wl,--enable-auto-image-base -Wl,--output-def,$[@].def,--out-implib,$[@].a -Wl,--export-all-symbols -Wl,--add-stdcall-alias'
			;;
	esac
])

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
		LIBS="${LIBS} ${TCL_LIBS}"

		KITDLL_LIB_VERSION=`echo "${TCL_VERSION}${TCL_PATCH_LEVEL}" | sed 's@\.@@g'`
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LIBS)

	AC_SUBST(KITDLL_LIB_VERSION)

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

		CFLAGS="${CFLAGS} ${TK_INCLUDE_SPEC} -I${tkconfigshdir} -I${TK_SRC_DIR}/generic -I${TK_SRC_DIR}/xlib"
		CPPFLAGS="${CPPFLAGS} ${TK_INCLUDE_SPEC} -I${tkconfigshdir} -I${TK_SRC_DIR}/generic -I${TK_SRC_DIR}/xlib"
		LIBS="${LIBS} ${TK_LIBS}"

		NEWLIBS=""
		for lib in ${LIBS}; do
			if echo "${lib}" | grep '^-l' >/dev/null; then
				if echo " ${NEWLIBS} " | grep " ${lib} " >/dev/null; then
					continue
				fi
			fi

			NEWLIBS="${NEWLIBS} ${lib}"
		done
		LIBS="${NEWLIBS}"
		unset NEWLIBS
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LIBS)

	AC_MSG_RESULT([$tkconfigsh])
])

AC_DEFUN(DC_SETUP_TCL_PLAT_DEFS, [
	AC_CANONICAL_HOST
  
	AC_MSG_CHECKING(host operating system)
	AC_MSG_RESULT($host_os)
  
	case $host_os in
		mingw32*)
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

AC_DEFUN(DC_TEST_WHOLE_ARCHIVE_SHARED_LIB, [

	SAVE_LIBS="${LIBS}"

	LIBS="${WHOLEARCHIVE} $1 ${NOWHOLEARCHIVE} ${SAVE_LIBS}"
	AC_LINK_IFELSE(
		AC_LANG_PROGRAM([[
			]], [[
			]]
		),
		[
			LIBS="${SAVE_LIBS}"

			$2
		], [
			LIBS="${SAVE_LIBS}"

			$3
		]
	)
])

AC_DEFUN(DC_DO_STATIC_LINK_LIB, [
	AC_MSG_CHECKING([for how to statically link to $1])
	 
	SAVELIBS="${LIBS}"
	staticlib=""
	found="0"
	dnl HP/UX uses -Wl,-a,archive -lstdc++ -Wl,-a,shared_archive
	dnl Linux and Solaris us -Wl,-Bstatic ... -Wl,-Bdynamic
	for trylink in "-Wl,-a,archive $2 -Wl,-a,shared_archive" "-Wl,-Bstatic $2 -Wl,-Bdynamic" "$2"; do
		LIBS="${SAVELIBS} ${trylink}"
	       
		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []), [
			staticlib="${trylink}"
			found="1"
	       
			break
		])
	done   
	 
	if test "${found}" = "1"; then
		SAVELIBS=`echo "$SAVELIBS" | sed 's@ $2 @ @'`
		LIBS="${SAVELIBS} ${staticlib}"

		AC_MSG_RESULT([${staticlib}])

		AC_SUBST(LIBS)

		$3
	else    
		LIBS="${SAVELIBS}"
		
		AC_MSG_RESULT([cant])
		
		$4
	fi
])

AC_DEFUN(DC_DO_STATIC_LINK_LIBCXX, [
	dnl Sun Studio uses -lCstd -lCrun, most platforms use -lstdc++
	DC_DO_STATIC_LINK_LIB([C++ Library (Sun Studio)], [-lCstd -lCrun],, [
		DC_DO_STATIC_LINK_LIB([C++ Library (UNIX)], [-lstdc++])
	])
])

AC_DEFUN(DC_FIND_TCLKIT_LIBS, [
	AC_CHECK_TOOL(OBJCOPY, objcopy, [:])

	DC_SETUP_TCL_PLAT_DEFS

	WISH_CFLAGS=""

	dnl We will need this for the Tcl project, which we will always have
	DC_CHECK_FOR_WHOLE_ARCHIVE

	for proj in tcl tclvfs tk mk4tcl; do
		AC_MSG_CHECKING([for libraries required for ${proj}])

		libdir="../../../${proj}/inst"
		libfiles="`find "${libdir}" -name '*.a' 2>/dev/null | tr "\n" ' '`"
		libfilesnostub="`find "${libdir}" -name '*.a' 2>/dev/null | grep -v 'stub' | tr "\n" ' '`"

		for libfile in ${libfiles}; do
			LDFLAGS="${LDFLAGS} -L`dirname "${libfile}"`"
		done

		hide_symbols="1"

		if test "$proj" = "tcl"; then
			DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $libfilesnostub], [
				libfiles="${libfilesnostub}"
			], [
				DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $libfiles], [
					libfiles="${libfiles}"
				])
			])

			hide_symbols="0"
		fi

		if test "${proj}" = "mk4tcl"; then
			if test -n "$libfiles"; then
				AC_DEFINE(KIT_INCLUDES_MK4TCL, [1], [Specify this if you link against mkt4tcl])
				DC_DO_STATIC_LINK_LIBCXX
			fi
		fi

		if test "$proj" = "tk"; then
			if test -n "$libfilesnostub"; then
				DC_DO_TK
				DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $libfilesnostub], [
					libfiles="${libfilesnostub}"
				], [
					DC_TEST_WHOLE_ARCHIVE_SHARED_LIB([$ARCHS $libfiles], [
						libfiles="${libfiles}"
					])
				])

				AC_DEFINE(KIT_INCLUDES_TK, [1], [Specify this if we link statically to Tk])

				if test -n "${TK_VERSION}"; then
					AC_DEFINE_UNQUOTED(KIT_TK_VERSION, "${TK_VERSION}${TK_PATCH_LEVEL}", [Specify the version of Tk])
				fi

				if test "$host_os" = "mingw32msvc" -o "$host_os" = "mingw32"; then
					WISH_CFLAGS="-mwindows"
				fi

				hide_symbols="0"
			fi
		fi

		ARCHS="${ARCHS} ${libfiles}"

		AC_MSG_RESULT([${libfiles}])

		if test "${hide_symbols}" = "1"; then
			STRIPLIBS="${STRIPLIBS} ${libfiles}"
		fi

	done

	AC_SUBST(WISH_CFLAGS)
	AC_SUBST(ARCHS)
	AC_SUBST(STRIPLIBS)
])

AC_DEFUN(DC_CHECK_FOR_ACCEPTABLE_DLADDR, [
	AC_CHECK_HEADERS(dlfcn.h)
	AC_CHECK_FUNCS(dladdr)

	AC_MSG_CHECKING([for acceptable dladdr])

	AC_LINK_IFELSE(
		AC_LANG_PROGRAM([[
#ifdef HAVE_DLFCN_H
#include <dlfcn.h>
#endif
			]], [[
char *x;
Dl_info syminfo;
dladdr((void *) 0, &syminfo);
x = syminfo.dli_fname;
			]]
		),
		[
			AC_MSG_RESULT([found])
			AC_DEFINE(HAVE_ACCEPTABLE_DLADDR, [1], [Define to 1 if you have an acceptable dladdr implementation with dli_fname])
		], [
			AC_MSG_RESULT([not found])
		]
	)
])

AC_DEFUN(DC_CHECK_FOR_WHOLE_ARCHIVE, [
	AC_MSG_CHECKING([for how to link whole archive])

	SAVE_CFLAGS="${CFLAGS}"

	wholearchive=""

	for check in "-Wl,--whole-archive -Wl,--no-whole-archive" "-Wl,-z,allextract -Wl,-z,defaultextract"; do
		CFLAGS="${SAVE_CFLAGS} ${check}"

		AC_LINK_IFELSE(AC_LANG_PROGRAM([], []),
			[
				wholearchive="${check}"

				break
			]
		)

	done

	CFLAGS="${SAVE_CFLAGS}"

	if test -z "${wholearchive}"; then
		AC_MSG_RESULT([not found])
	else
		AC_MSG_RESULT([${wholearchive}])

		WHOLEARCHIVE=`echo "${wholearchive}" | cut -f 1 -d ' '`
		NOWHOLEARCHIVE=`echo "${wholearchive}" | cut -f 2 -d ' '`
	fi

	AC_SUBST(WHOLEARCHIVE)
	AC_SUBST(NOWHOLEARCHIVE)
])
