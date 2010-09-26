AC_DEFUN(DC_DO_NETWORK, [
	AC_SEARCH_LIBS(inet_aton, xnet ws2_32 wsock32, [
		AC_DEFINE(HAVE_INET_ATON, [], [Have inet_aton()])
	], [
		AC_SEARCH_LIBS(inet_addr, nsl ws2_32 wsock32, [
			AC_DEFINE(HAVE_INET_ADDR, [], [Have inet_addr()])
		], [
			AC_MSG_WARN([could not find inet_addr or inet_aton!])
		])
	])

	AC_SEARCH_LIBS(inet_ntoa, socket nsl ws2_32 wsock32,, [ AC_MSG_WARN([Couldn't find inet_ntoa!]) ])
	AC_SEARCH_LIBS(connect, socket nsl ws2_32 wsock32,, [ AC_MSG_WARN([Couldn't find connect!]) ])
	AC_SEARCH_LIBS(socket, socket nsl ws2_32 wsock32,, [ AC_MSG_WARN([Couldn't find socket!]) ])
])

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


	source "${tclconfigsh}"

	CFLAGS="${CFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic"
	CPPFLAGS="${CPPFLAGS} ${TCL_INCLUDE_SPEC} -I${TCL_SRC_DIR}/generic"
	LDFLAGS="${LDFLAGS}"

	AC_SUBST(CFLAGS)
	AC_SUBST(CPPFLAGS)
	AC_SUBST(LDFLAGS)

	AC_MSG_RESULT([$tclconfigsh])
])

AC_DEFUN(DC_DO_STATIC_LINK_LIBCXX, [
	AC_MSG_CHECKING([for how to statically link to libstdc++])

	STATICLIBCXX="-Wl,-Bstatic -lstdc++ -Wl,-Bdynamic"
	LIBS="${LDFLAGS} ${STATICLIBCXX}"

	AC_SUBST(LIBS)

	AC_MSG_RESULT([${STATICLIBCXX}])
])
