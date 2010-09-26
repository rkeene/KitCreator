/* 
 * tclAppInit.c --
 *
 *  Provides a default version of the main program and Tcl_AppInit
 *  procedure for Tcl applications (without Tk).  Note that this
 *  program must be built in Win32 console mode to work properly.
 *
 * Copyright (c) 1996-1997 by Sun Microsystems, Inc.
 * Copyright (c) 1998-1999 by Scriptics Corporation.
 * Copyright (c) 2000-2002 Jean-Claude Wippler <jcw@equi4.com>
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * RCS: @(#) $Id$
 */

#ifdef KIT_INCLUDES_TK
#  include <tk.h>
#else
#  include <tcl.h>
#endif /* KIT_INCLUDES_TK */

#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  undef WIN32_LEAN_AND_MEAN
#endif /* _WIN32 */

#ifndef MB_TASKMODAL
#  define MB_TASKMODAL 0
#endif /* MB_TASKMODAL */

#include "tclInt.h"

#if defined(HAVE_TCL_GETENCODINGNAMEFROMENVIRONMENT) && defined(HAVE_TCL_SETSYSTEMENCODING)
#  define TCLKIT_CAN_SET_ENCODING 1
#endif
#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 85
#  define TCLKIT_REQUIRE_TCLEXECUTABLENAME 1
#endif

#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 85
#  define KIT_INCLUDES_PWB 1
#endif
#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 86
#  define KIT_INCLUDES_ZLIB 1
#endif

#ifdef KIT_INCLUDES_ITCL
Tcl_AppInitProc	Itcl_Init;
#endif
#ifdef KIT_INCLUDES_MK4TCL
Tcl_AppInitProc	Mk4tcl_Init;
#endif
Tcl_AppInitProc Vfs_Init, Rechan_Init;
#ifdef KIT_INCLUDES_PWB
Tcl_AppInitProc	Pwb_Init;
#endif
#ifdef KIT_INCLUDES_ZLIB
Tcl_AppInitProc Zlib_Init;
#endif
#ifdef TCL_THREADS
Tcl_AppInitProc	Thread_Init;
#endif
#ifdef _WIN32
Tcl_AppInitProc	Dde_Init, Registry_Init;
#endif

/* Determine which type of storage to use -- MK4 or ZIP */
#if defined(KIT_STORAGE_MK4) && defined(KIT_STORAGE_ZIP)
#  undef KIT_STORAGE_ZIP
#endif
#if !defined(KIT_STORAGE_MK4) && !defined(KIT_STORAGE_ZIP)
#  ifdef KIT_INCLUDES_MK4TCL
#    define KIT_STORAGE_MK4 1
#  else
#    define KIT_STORAGE_ZIP 1
#  endif
#endif

#ifdef TCLKIT_REQUIRE_TCLEXECUTABLENAME
char *tclExecutableName;
#endif

    /*
     *  Attempt to load a "boot.tcl" entry from the embedded MetaKit file.
     *  If there isn't one, try to open a regular "setup.tcl" file instead.
     *  If that fails, this code will throw an error, using a message box.
     */

static char *preInitCmd = 
#ifdef _WIN32_WCE
/* silly hack to get wince port to launch, some sort of std{in,out,err} problem */
"open /kitout.txt a; open /kitout.txt a; open /kitout.txt a\n"
/* this too seems to be needed on wince - it appears to be related to the above */
"catch {rename source ::tcl::source}\n"
"proc source file {\n"
	"set old [info script]\n"
	"info script $file\n"
	"set fid [open $file]\n"
	"set data [read $fid]\n"
	"close $fid\n"
	"set code [catch {uplevel 1 $data} res]\n"
	"info script $old\n"
	"if {$code == 2} { set code 0 }\n"
	"return -code $code $res\n"
"}\n"
#endif /* _WIN32_WCE */
"proc tclKitInit {} {\n"
	"rename tclKitInit {}\n"
#ifdef KIT_INCLUDES_MK4TCL
	"catch { load {} Mk4tcl }\n"
#endif
#ifdef KIT_STORAGE_MK4
	"set ::tclKitStorage \"mk4\"\n"
	"mk::file open exe [info nameofexecutable] -readonly\n"
	"set n [mk::select exe.dirs!0.files name boot.tcl]\n"
	"if {$n != \"\"} {\n"
		"set s [mk::get exe.dirs!0.files!$n contents]\n"
		"if {![string length $s]} { error \"empty boot.tcl\" }\n"
		"catch {load {} zlib}\n"
		"if {[mk::get exe.dirs!0.files!$n size] != [string length $s]} {\n"
			"set s [zlib decompress $s]\n"
		"}\n"
	"}\n"
#endif /* KIT_STORAGE_MK4 */
#ifdef KIT_STORAGE_ZIP
	"set ::tclKitStorage \"zip\"\n"
	"catch { load {} vfs }\n"
	"if {[lsearch -exact [vfs::filesystem info] [info nameofexecutable]] != -1} {"
		"set s \"\"\n"
	"}\n"
	"if {![info exists s]} {\n"
#  include "zipvfs.tcl.h"
		"catch {\n"
			"set ::tclKitStorage_fd [::zip::open [info nameofexecutable]]\n"
		"} err\n"
		"if {![catch { ::zip::stat $::tclKitStorage_fd boot.tcl sb }]} {\n"
			"catch {\n"
				"seek $::tclKitStorage_fd $sb(ino)\n"
				"zip::Data $::tclKitStorage_fd sb s\n"
			"}\n"
		"}\n"
	"}\n"
#endif /* KIT_STORAGE_ZIP */
	"if {![info exists s]} {\n"
		"set f [open setup.tcl]\n"
		"set s [read $f]\n"
		"close $f\n"
	"}\n"
	"uplevel #0 $s\n"
#if defined(KIT_INCLUDES_TK) && defined(KIT_TK_VERSION)
#  ifndef _WIN32
	"package ifneeded Tk " KIT_TK_VERSION " {\n"
		"load {} Tk\n"
	"}\n"
#  endif
#endif
#ifdef _WIN32
	"catch {load {} dde}\n"
	"catch {load {} registry}\n"
#endif /* _WIN32 */
	"return 0\n"
"}\n"
"tclKitInit";

static const char initScript[] =
"if {[file isfile [file join [info nameofexe] main.tcl]]} {\n"
	"if {[info commands console] != {}} { console hide }\n"
	"set tcl_interactive 0\n"
	"incr argc\n"
	"set argv [linsert $argv 0 $argv0]\n"
	"set argv0 [file join [info nameofexe] main.tcl]\n"
"} else continue\n";

/* SetExecName --

   Hack to get around Tcl bug 1224888.
*/
static void SetExecName(Tcl_Interp *interp, const char *path) {
#ifdef TCLKIT_REQUIRE_TCLEXECUTABLENAME
	tclExecutableName = strdup(path);
#endif
	Tcl_FindExecutable(path);

	return;
}

static void FindAndSetExecName(Tcl_Interp *interp) {
	int len = 0;
	Tcl_Obj *execNameObj;
	Tcl_Obj *lobjv[1];
#if defined(HAVE_READLINK)
	ssize_t readlink_ret;
	char procpath[4096];
	char exe_buf[4096];
	int snprintf_ret;

	if (Tcl_GetNameOfExecutable() == NULL) {
		snprintf_ret = snprintf(procpath, sizeof(procpath), "/proc/%lu/exe", (unsigned long) getpid());
		if (snprintf_ret < sizeof(procpath)) {
			readlink_ret = readlink(procpath, exe_buf, sizeof(exe_buf) - 1);

			if (readlink_ret > 0 && readlink_ret < (sizeof(exe_buf) - 1)) {
				exe_buf[readlink_ret] = '\0';

				SetExecName(interp, exe_buf);

				return;
			}
		}
	}
#endif

	if (Tcl_GetNameOfExecutable() == NULL) {
		lobjv[0] = Tcl_GetVar2Ex(interp, "argv0", NULL, TCL_GLOBAL_ONLY);
		execNameObj = Tcl_FSJoinToPath(Tcl_FSGetCwd(interp), 1, lobjv);

		SetExecName(interp, Tcl_GetStringFromObj(execNameObj, &len));

		return;
	}

	return;
}

int TclKit_AppInit(Tcl_Interp *interp) {
#ifdef TCLKIT_CAN_SET_ENCODING
	Tcl_DString encodingName;
#endif

#ifdef KIT_INCLUDES_ITCL
	Tcl_StaticPackage(0, "Itcl", Itcl_Init, NULL);
#endif 
#ifdef KIT_INCLUDES_MK4TCL
	Tcl_StaticPackage(0, "Mk4tcl", Mk4tcl_Init, NULL);
#endif
#ifdef KIT_INCLUDES_PWB
	Tcl_StaticPackage(0, "pwb", Pwb_Init, NULL);
#endif 
	Tcl_StaticPackage(0, "rechan", Rechan_Init, NULL);
	Tcl_StaticPackage(0, "vfs", Vfs_Init, NULL);
#ifdef KIT_INCLUDES_ZLIB
	Tcl_StaticPackage(0, "zlib", Zlib_Init, NULL);
#endif
#ifdef TCL_THREADS
	Tcl_StaticPackage(0, "Thread", Thread_Init, NULL);
#endif
#ifdef _WIN32
	Tcl_StaticPackage(0, "dde", Dde_Init, NULL);
	Tcl_StaticPackage(0, "registry", Registry_Init, NULL);
#endif
#ifdef KIT_INCLUDES_TK
	Tcl_StaticPackage(0, "Tk", Tk_Init, Tk_SafeInit);
#endif

	/* the tcl_rcFileName variable only exists in the initial interpreter */
#ifdef _WIN32
	Tcl_SetVar(interp, "tcl_rcFileName", "~/tclkitrc.tcl", TCL_GLOBAL_ONLY);
#else
	Tcl_SetVar(interp, "tcl_rcFileName", "~/.tclkitrc", TCL_GLOBAL_ONLY);
#endif

#ifdef TCLKIT_CAN_SET_ENCODING
	/* Set the encoding from the Environment */
	Tcl_GetEncodingNameFromEnvironment(&encodingName);
	Tcl_SetSystemEncoding(NULL, Tcl_DStringValue(&encodingName));
	Tcl_SetVar(interp, "tclkit_system_encoding", Tcl_DStringValue(&encodingName), 0);
	Tcl_DStringFree(&encodingName);
#endif

	/* Hack to get around Tcl bug 1224888.  This must be run here and
	 * in LibraryPathObjCmd because this information is needed both
	 * before and after that command is run. */
	FindAndSetExecName(interp);

	TclSetPreInitScript(preInitCmd);
	if (Tcl_Init(interp) == TCL_ERROR) {
		goto error;
	}

#ifdef KIT_INCLUDES_TK
#  ifdef _WIN32
	if (Tk_Init(interp) == TCL_ERROR) {
		goto error;
	}
	if (Tk_CreateConsoleWindow(interp) == TCL_ERROR) {
		goto error;
	}
#  endif /* _WIN32 */
#endif /* KIT_INCLUDES_TK */

	/* messy because TclSetStartupScriptPath is called slightly too late */
	if (Tcl_Eval(interp, initScript) == TCL_OK) {
		Tcl_Obj* path;
#ifdef HAVE_TCLSETSTARTUPSCRIPTPATH
		path = TclGetStartupScriptPath();
		TclSetStartupScriptPath(Tcl_GetObjResult(interp));
#elif defined(HAVE_TCL_SETSTARTUPSCRIPT)
		path = Tcl_GetStartupScript(NULL);
		Tcl_SetStartupScript(Tcl_GetObjResult(interp), NULL);
#endif
		if (path == NULL) {
			Tcl_Eval(interp, "incr argc -1; set argv [lrange $argv 1 end]");
		}
	}

	Tcl_SetVar(interp, "errorInfo", "", TCL_GLOBAL_ONLY);
	Tcl_ResetResult(interp);

	return TCL_OK;

error:
#ifdef KIT_INCLUDES_TK
#  ifdef _WIN32
	MessageBeep(MB_ICONEXCLAMATION);
#    ifndef _WIN32_WCE
	MessageBox(NULL, Tcl_GetStringResult(interp), "Error in TclKit",
	           MB_ICONSTOP | MB_OK | MB_TASKMODAL | MB_SETFOREGROUND);

	ExitProcess(1);
#    endif /* !_WIN32_WCE */
    /* we won't reach this, but we need the return */
#  endif /* _WIN32 */
#endif /* KIT_INCLUDES_TK */

	return TCL_ERROR;
}
