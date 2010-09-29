#include <stdio.h>
#include <tcl.h>
#include "tclInt.h"

Tcl_AppInitProc Vfs_Init, Rechan_Init;
Tcl_AppInitProc Vfs_kitdll_data_tcl_Init;

static char *preInitCmd =
"proc tclKitInit {} {\n"
"puts \"Ran tclKitInit\"\n"
	"rename tclKitInit {}\n"
	"load {} rechan\n"
	"load {} vfs\n"
	"load {} vfs_kitdll_data_tcl\n"
"puts \"Loaded VFS\"\n"
#include "vfs_kitdll.tcl.h"
	"vfs::kitdll::Mount tcl /.KITDLL_TCL\n"
"puts \"Mounted VFS\"\n"
	"set f [open \"/.KITDLL_TCL/boot.tcl\"]\n"
	"set s [read $f]\n"
	"close $f\n"
	"uplevel #0 $s\n"
"}\n"
"tclKitInit";

void __attribute__((constructor)) _Tclkit_Init(void) {
	int tcl_ret = -1;

	Tcl_StaticPackage(0, "rechan", Rechan_Init, NULL);
	Tcl_StaticPackage(0, "vfs", Vfs_Init, NULL);
	Tcl_StaticPackage(0, "vfs_kitdll_data_tcl", Vfs_kitdll_data_tcl_Init, NULL);

	TclSetPreInitScript(preInitCmd);
	printf("TclSetPreInitScript() = %i\n", tcl_ret);

	return;
}
