dnl What are we running
AC_INIT(kitsh, 0.0)

dnl Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_INSTALL
AC_AIX
AC_GNU_SOURCE

dnl Find out if we should build a DLL or an Executable
TARGET="tclkit"
AC_MSG_CHECKING([what target to build])
AC_ARG_ENABLE(kitdll, AC_HELP_STRING([--enable-kitdll], [Enable building KitDLL instead of Tclkit (default: no)]), [
	case "$enableval" in
		yes|kitdll)
			TARGET="kitdll"
			;;
		no)
			true
			;;
		*)
			AC_MSG_RESULT([unknown])

			AC_MSG_ERROR([Invalid option: $enableval])
			;;
	esac
])
AC_MSG_RESULT([$TARGET])

dnl Find the appropriate libraries to link to
AC_SEARCH_LIBS(acos, m,, [ AC_MSG_WARN([Couldn't find acos (normally in libm)!]) ])
AC_SEARCH_LIBS(dlsym, dl,, [ AC_MSG_WARN([Couldn't find dlsym (normally in libdl)!]) ])

if test "$TARGET" = "tclkit"; then
	dnl Figure out how to statically link to libgcc, if needed
	DC_STATIC_LIBGCC
else
	dnl We have KitDLL

	dnl Determine system information
	DC_CHK_OS_INFO

	dnl Determine how to create a shared object
	DC_GET_SHOBJFLAGS

	dnl KitDLL always uses C-VFS
	AC_DEFINE([KIT_STORAGE_CVFS], [1], [Define if you are going to use C-VFS for kit storage])

	dnl Define KitDLL usage
	AC_DEFINE([TCLKIT_DLL], [1], [Define if you are using a KitDLL rather than a Tclkit])
fi

dnl Find the appropriate Tcl headers and libraries
DC_DO_TCL

dnl Find archives we need to link to
DC_FIND_TCLKIT_LIBS

dnl Find extra objects we need to link as a part of "kit"
AC_SUBST(EXTRA_OBJS)

dnl Check for Windows Resource Compiler
AC_CHECK_TOOL([RC], [windres], [false])

dnl If we found the resource compiler, add "kit.res.o" to our list of objects to build
dnl (as long as the source for such an object exists)
if ! test "$RC" = "false"; then
	if test -f kit.rc; then
		EXTRA_OBJS="$EXTRA_OBJS kit.res.o"
	fi
fi

dnl Check for Tcl features
SAVE_LIBS="${LIBS}"
LIBS="${ARCHS} ${LIBS}"

dnl Determine if we have "Tcl_SetStartupScript" (8.6.x) or "TclSetStartupScriptPath" (8.4.x)
AC_CHECK_FUNCS(Tcl_SetStartupScript TclSetStartupScriptPath)

dnl Check for the ability to get the current system encoding
AC_CHECK_FUNCS(Tcl_GetEncodingNameFromEnvironment Tcl_SetSystemEncoding)
LIBS="${SAVE_LIBS}"

dnl Check for optional headers
AC_HEADER_STDC
AC_CHECK_HEADERS(unistd.h string.h strings.h)

dnl Check for optional system calls
AC_CHECK_FUNCS(readlink)

dnl Check for acceptable dladdr so we can find ourselves on Solaris
DC_CHECK_FOR_ACCEPTABLE_DLADDR

dnl Find zlib
AC_ARG_WITH(zlib, AC_HELP_STRING([--with-zlib], [directory containing zlib]), [
	CPPFLAGS="${CPPFLAGS} -I${with_zlib}/include -I${with_zlib}"
	CFLAGS="${CFLAGS} -I${with_zlib}/include -I${with_zlib}"
	LDFLAGS="${LDFLAGS} -L${with_zlib}/lib -L${with_zlib}"
])

dnl Only needed for Tclkit
if test "$TARGET" = "tclkit"; then
	DC_DO_STATIC_LINK_LIB(zlib, -lz,, [
		DC_DO_STATIC_LINK_LIB(zlib, -lzlib,, [
			AC_SEARCH_LIBS(inflate, z zlib,, [
				AC_MSG_WARN([Couldn't find inflate (normally in zlib)!])
			])
		])
	])
fi

dnl Determine which storage mechanism to use
AC_MSG_CHECKING([which Tclkit Storage mechanism to use])

storage_mech="auto"
AC_ARG_ENABLE(kit-storage, AC_HELP_STRING([--enable-kit-storage={zip|mk4|cvfs}], [Specify storage mechanism to use for built-in VFS (default: auto)]), [
	case "$enableval" in
		mk4)
			storage_mech="mk4"

			AC_DEFINE([KIT_STORAGE_MK4], [1], [Define if you are going to use Metakit4 for kit storage])
			;;
		zip)
			storage_mech="zip"

			AC_DEFINE([KIT_STORAGE_ZIP], [1], [Define if you are going to use ZIP for kit storage])
			;;
		cvfs)
			storage_mech="cvfs"

			AC_DEFINE([KIT_STORAGE_CVFS], [1], [Define if you are going to use C-VFS for kit storage])
			;;
		yes)
			# If they just want to enable kit storage, but nothing specifically, do nothing
			storage_mech="auto"
			;;
		auto)
			# Auto is how it works by default
			storage_mech="auto"
			;;
		no)
			# You can't disable kit storage
			AC_MSG_RESULT([fail])
			AC_MSG_ERROR([Kit Storage cannot be disabled])
			;;
		*)
			AC_MSG_RESULT([fail])
			AC_MSG_ERROR([Unknown kit storage type: $enableval])
			;;
	esac
])
AC_MSG_RESULT([$storage_mech])

dnl Verify sanity of storage mechanism
if ! test "$TARGET" = "tclkit"; then
	case "$storage_mech" in
		auto|cvfs)
			true
			;;
		*)
			AC_MSG_ERROR([Only "cvfs" and "auto" are valid storage mechanisms when building KitDLL])
			;;
	esac
fi

dnl Put correct Makefile template in place
rm -f Makefile.in
cp Makefile.${TARGET}.in Makefile.in

dnl Produce output
AC_OUTPUT(Makefile)
