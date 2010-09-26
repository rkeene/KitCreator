dnl What are we running
AC_INIT(kitsh, 0.0)
AC_CONFIG_HEADER(config.h)

dnl Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_INSTALL
AC_AIX
AC_GNU_SOURCE

dnl Check for network libraries
DC_DO_NETWORK

dnl Find the appropriate Tcl headers and libraries
DC_DO_TCL

dnl Find out how to statically link to libstdc++ (for Metakit)
DC_DO_STATIC_LINK_LIBCXX

dnl Find the appropriate libraries to link to
AC_SEARCH_LIBS(inflate, z zlib,, [ AC_MSG_WARN([Couldn't find inflate (normally in zlib)!]) ])
AC_SEARCH_LIBS(acos, m,, [ AC_MSG_WARN([Couldn't find acos (normally in libm)!]) ])
AC_SEARCH_LIBS(dlsym, dl,, [ AC_MSG_WARN([Couldn't find dlsym (normally in libdl)!]) ])

dnl Produce output
AC_OUTPUT(Makefile)
