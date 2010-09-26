AC_DEFUN(DC_DO_TCL, [
	AC_MSG_CHECKING([path to tcl])
	AC_ARG_WITH(tcl, AC_HELP_STRING([--with-tcl], [directory containing tcl configuration (tclConfig.sh)]), [], [
		with_tcl="auto"
	])

	if test "${with_tcl}" = "auto"; then
		for dir in `echo "${PATH}" | sed 's@:@ @g'`; do
			if test -f "${dir}/../lib/tclConfig.sh"; then
				tclconfigsh="${dir}/../lib/tclConfig.sh"
				break
			fi
			if test -f "${dir}/../lib64/tclConfig.sh"; then
				tclconfigsh="${dir}/../lib64/tclConfig.sh"
				break
			fi
		done

		if test -z "${tclconfigsh}"; then
			AC_MSG_ERROR([Unable to find tclConfig.sh])
		fi
	else
		tclconfigsh="${with_tcl}/tclConfig.sh"
	fi

	if test -f "${tclconfigsh}"; then
		source "${tclconfigsh}"

		CFLAGS="${CFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic"
		CPPFLAGS="${CPPFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic"
		LDFLAGS="${LDFLAGS}"
		LIBS="${LIBS} ${TCL_LIBS}"
	fi

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LDFLAGS)
	AC_SUBST(LIBS)

	AC_MSG_RESULT([$tclconfigsh])
])

AC_DEFUN(DC_DO_STATIC_LINK_LIBCXX, [
	AC_MSG_CHECKING([for how to statically link to libstdc++])

	STATICLIBCXX="-Wl,-Bstatic -lstdc++ -Wl,-Bdynamic"
	LIBS="${LIBS} ${STATICLIBCXX}"

	AC_SUBST(LIBS)

	AC_MSG_RESULT([${STATICLIBCXX}])
])
