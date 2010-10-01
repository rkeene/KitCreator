dnl What are we running
AC_INIT(kitdll, 0.0)

dnl Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_INSTALL
AC_AIX
AC_GNU_SOURCE

dnl Determine system information
DC_CHK_OS_INFO

dnl Find the appropriate libraries to link to
AC_SEARCH_LIBS(acos, m,, [ AC_MSG_WARN([Couldn't find acos (normally in libm)!]) ])
AC_SEARCH_LIBS(dlsym, dl,, [ AC_MSG_WARN([Couldn't find dlsym (normally in libdl)!]) ])

dnl Determine how to create a shared object
DC_GET_SHOBJFLAGS

dnl Find the appropriate Tcl headers and libraries
DC_DO_TCL

dnl Check for Tcl features
SAVE_LIBS="${LIBS}"
LIBS="${ARCHS} ${LIBS}"
dnl Check for the ability to get the current system encoding
AC_CHECK_FUNCS(Tcl_GetEncodingNameFromEnvironment Tcl_SetSystemEncoding)
LIBS="${SAVE_LIBS}"

dnl Find required libs
DC_FIND_TCLKIT_LIBS

dnl Find extra objects we need to link as a part of "libtclkit"
AC_SUBST(EXTRA_OBJS)

dnl Check for optional headers
AC_HEADER_STDC
AC_CHECK_HEADERS(unistd.h string.h strings.h)

dnl Check for optional system calls
AC_CHECK_FUNCS(readlink)

dnl Check for acceptable dladdr so we can find ourselves on UNIX
DC_CHECK_FOR_ACCEPTABLE_DLADDR

dnl Produce output
AC_OUTPUT(Makefile)
