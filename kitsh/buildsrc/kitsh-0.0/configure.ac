dnl What are we running
AC_INIT(kitsh, 0.0)

dnl Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_INSTALL
AC_AIX
AC_GNU_SOURCE

dnl Find the appropriate libraries to link to
AC_SEARCH_LIBS(acos, m,, [ AC_MSG_WARN([Couldn't find acos (normally in libm)!]) ])
AC_SEARCH_LIBS(dlsym, dl,, [ AC_MSG_WARN([Couldn't find dlsym (normally in libdl)!]) ])

dnl Figure out how to statically link to libgcc, if needed
DC_STATIC_LIBGCC

dnl Find the appropriate Tcl headers and libraries
DC_DO_TCL

dnl Find archives we need to link to
DC_FIND_TCLKIT_LIBS

dnl Determine if we have "Tcl_SetStartupScript" (8.6.x) or "TclSetStartupScriptPath" (8.4.x)
SAVE_LIBS="${LIBS}"
LIBS="${ARCHS} ${LIBS}"
AC_CHECK_FUNCS(Tcl_SetStartupScript TclSetStartupScriptPath)
LIBS="${SAVE_LIBS}"

dnl Find zlib
AC_ARG_WITH(zlib, AC_HELP_STRING([--with-zlib], [directory containing zlib]), [
	CFLAGS="${CFLAGS} -I${with_zlib}/include -I${with_zlib}"
	LDFLAGS="${LDFLAGS} -L${with_zlib}/lib -L${with_zlib}"
])
AC_SEARCH_LIBS(inflate, z zlib,, [ AC_MSG_WARN([Couldn't find inflate (normally in zlib)!]) ])

dnl Produce output
AC_OUTPUT(Makefile)
