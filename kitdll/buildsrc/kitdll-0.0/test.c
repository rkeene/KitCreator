#ifdef HAVE_STDIO_H
#  include <stdio.h>
#endif

#include <tcl.h>

int main(int argc, char **argv) {
	Tcl_Interp *interp;
	int tcl_ret;

	interp = Tcl_CreateInterp();
	if (interp == NULL) {
		fprintf(stderr, "Unable to create an interpreter.\n");

		return(1);
	}

	tcl_ret = Tcl_Init(interp);
	if (tcl_ret != TCL_OK) {
		fprintf(stderr, "Tcl_Init() returned in failure. %s\n", Tcl_GetVar(interp, "errorInfo", TCL_GLOBAL_ONLY));

		return(1);
	}

	tcl_ret = Tcl_Eval(interp, "puts \"Hello World. Current Time is: [clock format [clock seconds]]\"");
	if (tcl_ret != TCL_OK) {
		fprintf(stderr, "Tcl_Eval() returned in failure.\n");

		return(1);
	}

	Tcl_DeleteInterp(interp);

	return(0);
}
