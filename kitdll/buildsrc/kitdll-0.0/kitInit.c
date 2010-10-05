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

#ifdef HAVE_STRING_H
#  include <string.h>
#endif
#ifdef HAVE_STRINGS_H
#  include <strings.h>
#endif
#ifdef HAVE_DLFCN_H
#  include <dlfcn.h>
#endif

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

Tcl_AppInitProc Vfs_Init, Rechan_Init;
Tcl_AppInitProc Vfs_kitdll_data_tcl_Init;
#ifdef KIT_INCLUDES_MK4TCL
Tcl_AppInitProc Mk4tcl_Init;
#endif
#ifdef KIT_INCLUDES_PWB
Tcl_AppInitProc Pwb_Init;
#endif
#ifdef KIT_INCLUDES_ZLIB
Tcl_AppInitProc Zlib_Init;
#endif
#ifdef TCL_THREADS
Tcl_AppInitProc Thread_Init;
#endif
#ifdef _WIN32
Tcl_AppInitProc Dde_Init, Registry_Init;
#endif

/*
 * This Tcl code is invoked whenever Tcl_Init() is called on an
 * interpreter.  It should mount up the VFS and make everything ready for
 * that interpreter to do its job.
 */
static char *preInitCmd =
"proc tclKitInit {} {\n"
	"rename tclKitInit {}\n"
#ifdef KIT_INCLUDES_ZLIB
	"catch { load {} zlib }\n"
#endif
	"load {} tclkit::init\n"
	"load {} rechan\n"
	"load {} vfs\n"
	"load {} vfs_kitdll_data_tcl\n"
#ifdef KIT_INCLUDES_MK4TCL
	"catch { load {} Mk4tcl }\n"
#endif
#include "vfs_kitdll.tcl.h"
	"if {![file exists \"/.KITDLL_TCL/boot.tcl\"]} {\n"
		"vfs::kitdll::Mount tcl /.KITDLL_TCL\n"
		"set ::initVFS 1\n"
	"}\n"
	"set f [open \"/.KITDLL_TCL/boot.tcl\"]\n"
	"set s [read $f]\n"
	"close $f\n"
	"::tclkit::init::initInterp\n"
	"rename ::tclkit::init::initInterp {}\n"
	"uplevel #0 $s\n"
#if defined(KIT_INCLUDES_TK) && defined(KIT_TK_VERSION)
	"package ifneeded Tk " KIT_TK_VERSION " {\n"
		"load {} Tk\n"
	"}\n"
#endif
#ifdef _WIN32
	"catch {load {} dde}\n"
	"catch {load {} registry}\n"
#endif /* _WIN32 */
"}\n"
"tclKitInit";

#ifdef HAVE_ACCEPTABLE_DLADDR
/* Symbol to resolve against dladdr() */
static void _tclkit_dummy_func(void) {
	return;
}

int main(int argc, char **argv);
#endif /* HAVE_ACCEPTABLE_DLADDR */

/*
 * This function will return a pathname we can open() to treat as a VFS,
 * hopefully
 */
static char *find_tclkit_dll_path(void) {
#ifdef HAVE_ACCEPTABLE_DLADDR
	Dl_info syminfo;
	int dladdr_ret;
#endif /* HAVE_ACCEPTABLE_DLADDR */
#ifdef _WIN32
	TCHAR modulename[8192];
	DWORD gmfn_ret;
#endif /* _WIN32 */

#ifdef HAVE_ACCEPTABLE_DLADDR
	dladdr_ret = dladdr(&_tclkit_dummy_func, &syminfo);
	if (dladdr_ret != 0) {
		if (syminfo.dli_fname && syminfo.dli_fname[0] != '\0') {
			return(strdup(syminfo.dli_fname));
		}
	}
#endif /* HAVE_ACCEPTABLE_DLADDR */

#ifdef _WIN32
	gmfn_ret = GetModuleFileName(TclWinGetTclInstance(), modulename, sizeof(modulename) / sizeof(modulename[0]) - 1);

	if (gmfn_ret != 0) {
		return(strdup(modulename));
	}
#endif /* _WIN32 */

	return(NULL);
}

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
#ifdef HAVE_READLINK
	ssize_t readlink_ret;
	char exe_buf[4096];
#endif /* HAVE_READLINK */
#ifdef HAVE_ACCEPTABLE_DLADDR
	Dl_info syminfo;
	int dladdr_ret;
#endif /* HAVE_ACCEPTABLE_DLADDR */

#ifdef HAVE_READLINK
	if (Tcl_GetNameOfExecutable() == NULL) {
		readlink_ret = readlink("/proc/self/exe", exe_buf, sizeof(exe_buf) - 1);
		
		if (readlink_ret > 0 && readlink_ret < (sizeof(exe_buf) - 1)) {
			exe_buf[readlink_ret] = '\0';
			
			SetExecName(interp, exe_buf);
			
			return;
		}
	}
	
	if (Tcl_GetNameOfExecutable() == NULL) {
		readlink_ret = readlink("/proc/curproc/file", exe_buf, sizeof(exe_buf) - 1);												 

		if (readlink_ret > 0 && readlink_ret < (sizeof(exe_buf) - 1)) {
			exe_buf[readlink_ret] = '\0';

			if (strcmp(exe_buf, "unknown") != 0) {
				SetExecName(interp, exe_buf);

				return;
			}
		}
	}
#endif /* HAVE_READLINK */

#ifdef HAVE_ACCEPTABLE_DLADDR
	if (Tcl_GetNameOfExecutable() == NULL) {
		dladdr_ret = dladdr(&main, &syminfo);
		if (dladdr_ret != 0) {
			SetExecName(interp, syminfo.dli_fname);
		}
	}
#endif /* HAVE_ACCEPTABLE_DLADDR */

	if (Tcl_GetNameOfExecutable() == NULL) {
		lobjv[0] = Tcl_GetVar2Ex(interp, "argv0", NULL, TCL_GLOBAL_ONLY);
		execNameObj = Tcl_FSJoinToPath(Tcl_FSGetCwd(interp), 1, lobjv);

		SetExecName(interp, Tcl_GetStringFromObj(execNameObj, &len));

		return;
	}

	return;
}


/*
 * This function exists to allow C code to initialize a particular
 * interpreter.
 */
static int tclkit_init_initinterp(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	char *kitdll_path;
#ifdef TCLKIT_CAN_SET_ENCODING
	Tcl_DString encodingName;
#endif /* TCLKIT_CAN_SET_ENCODING */


#ifdef _WIN32
	Tcl_SetVar(interp, "tcl_rcFileName", "~/tclkitrc.tcl", TCL_GLOBAL_ONLY);
#else   
	Tcl_SetVar(interp, "tcl_rcFileName", "~/.tclkitrc", TCL_GLOBAL_ONLY);
#endif

	kitdll_path = find_tclkit_dll_path();
	if (kitdll_path != NULL) {
		Tcl_SetVar(interp, "tclKitFilename", kitdll_path, TCL_GLOBAL_ONLY);

		free(kitdll_path);
	}

	FindAndSetExecName(interp);

#ifdef TCLKIT_CAN_SET_ENCODING
	/* Set the encoding from the Environment */
	Tcl_GetEncodingNameFromEnvironment(&encodingName);
	Tcl_SetSystemEncoding(NULL, Tcl_DStringValue(&encodingName));
	Tcl_SetVar(interp, "tclkit_system_encoding", Tcl_DStringValue(&encodingName), TCL_GLOBAL_ONLY);
	Tcl_DStringFree(&encodingName);
#endif  

	return(TCL_OK);
}

/*
 * Create a package for initializing a particular interpreter.  This is
 * our hook to have Tcl invoke C commands when creating an interpreter.
 * The preInitCmd will load the package in the new interpreter and invoke
 * this function.
 */
int Tclkit_init_Init(Tcl_Interp *interp) {
	Tcl_Command tclCreatComm_ret;
	int tclPkgProv_ret;

	tclCreatComm_ret = Tcl_CreateObjCommand(interp, "::tclkit::init::initInterp", tclkit_init_initinterp, NULL, NULL);
	if (!tclCreatComm_ret) {
		return(TCL_ERROR);
	}

	tclPkgProv_ret = Tcl_PkgProvide(interp, "tclkit::init", "1.0");

	return(tclPkgProv_ret);
}

/*
 * Initialize the Tcl system when we are loaded, that way Tcl functions
 * are ready to be used when invoked.
 */
void __attribute__((constructor)) _Tclkit_Init(void) {
	Tcl_StaticPackage(0, "tclkit::init", Tclkit_init_Init, NULL);
	Tcl_StaticPackage(0, "rechan", Rechan_Init, NULL);
	Tcl_StaticPackage(0, "vfs", Vfs_Init, NULL);
	Tcl_StaticPackage(0, "vfs_kitdll_data_tcl", Vfs_kitdll_data_tcl_Init, NULL);
#ifdef KIT_INCLUDES_ZLIB
        Tcl_StaticPackage(0, "zlib", Zlib_Init, NULL);
#endif
#ifdef KIT_INCLUDES_MK4TCL
	Tcl_StaticPackage(0, "Mk4tcl", Mk4tcl_Init, NULL);
#endif
#ifdef KIT_INCLUDES_PWB
	Tcl_StaticPackage(0, "pwb", Pwb_Init, NULL);
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

	TclSetPreInitScript(preInitCmd);

	return;
}
