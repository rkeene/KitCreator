#include <tcl.h>
#include "tclInt.h"

#if defined(HAVE_TCL_GETENCODINGNAMEFROMENVIRONMENT) && defined(HAVE_TCL_SETSYSTEMENCODING)
#  define TCLKIT_CAN_SET_ENCODING 1
#endif
#if 10 * TCL_MAJOR_VERSION + TCL_MINOR_VERSION < 85
#  define KIT_INCLUDES_PWB 1
#endif

Tcl_AppInitProc Vfs_Init, Rechan_Init;
Tcl_AppInitProc Vfs_kitdll_data_tcl_Init;
#ifdef KIT_INCLUDES_PWB
Tcl_AppInitProc Pwb_Init;
#endif
#ifdef TCL_THREADS
Tcl_AppInitProc Thread_Init;
#endif
#ifdef _WIN32
Tcl_AppInitProc Dde_Init, Registry_Init;
#endif

static char *preInitCmd =
"proc tclKitInit {} {\n"
	"rename tclKitInit {}\n"
	"load {} tclkit::init\n"
	"load {} rechan\n"
	"load {} vfs\n"
	"load {} vfs_kitdll_data_tcl\n"
#include "vfs_kitdll.tcl.h"
	"vfs::kitdll::Mount tcl /.KITDLL_TCL\n"
	"set f [open \"/.KITDLL_TCL/boot.tcl\"]\n"
	"set s [read $f]\n"
	"close $f\n"
	"::tclkit::init::initInterp\n"
	"rename ::tclkit::init::initInterp {}\n"
	"uplevel #0 $s\n"
#ifdef _WIN32
	"catch {load {} dde}\n"
	"catch {load {} registry}\n"
#endif /* _WIN32 */
"}\n"
"tclKitInit";

static int tclkit_init_initinterp(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
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

	return(TCL_OK);
}

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

void __attribute__((constructor)) _Tclkit_Init(void) {
	Tcl_StaticPackage(0, "tclkit::init", Tclkit_init_Init, NULL);
	Tcl_StaticPackage(0, "rechan", Rechan_Init, NULL);
	Tcl_StaticPackage(0, "vfs", Vfs_Init, NULL);
	Tcl_StaticPackage(0, "vfs_kitdll_data_tcl", Vfs_kitdll_data_tcl_Init, NULL);
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

	TclSetPreInitScript(preInitCmd);

	return;
}
