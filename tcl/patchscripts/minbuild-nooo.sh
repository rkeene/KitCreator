#! /usr/bin/env bash

# Only apply to minimal builds
if [ -z "${KITCREATOR_MINBUILD}" ]; then
	exit 0
fi

# Only apply if the Tcl being built actually includes OO as part of Tcl
if [ ! -f 'generic/tclOO.c' ]; then
	exit 0
fi

# Apply OO-removing patch
patch -p1 << _EOF_
--- tclcvs_HEAD/generic/tclBasic.c	2012-09-07 16:01:14.000000000 -0500
+++ tclcvs_HEAD-OOremoved/generic/tclBasic.c	2012-09-09 13:44:06.618912251 -0500
@@ -820,8 +820,6 @@
      * Create unsupported commands for debugging bytecode and objects.
      */
 
-    Tcl_CreateObjCommand(interp, "::tcl::unsupported::disassemble",
-	    Tcl_DisassembleObjCmd, NULL, NULL);
     Tcl_CreateObjCommand(interp, "::tcl::unsupported::representation",
 	    Tcl_RepresentationCmd, NULL, NULL);
 
--- tclcvs_HEAD/generic/tclProc.c	2012-09-07 16:01:14.000000000 -0500
+++ tclcvs_HEAD-OOremoved/generic/tclProc.c	2012-09-09 13:45:16.634913713 -0500
@@ -2857,6 +2857,7 @@
  *----------------------------------------------------------------------
  */
 
+#if 0
 int
 Tcl_DisassembleObjCmd(
     ClientData dummy,		/* Not used. */
@@ -3072,6 +3073,7 @@
     Tcl_SetObjResult(interp, TclDisassembleByteCodeObj(codeObjPtr));
     return TCL_OK;
 }
+#endif
 
 /*
  * Local Variables:
--- tclcvs_HEAD/generic/tclVar.c	2012-09-07 16:01:14.000000000 -0500
+++ tclcvs_HEAD-OOremoved/generic/tclVar.c	2012-09-09 13:34:22.138912414 -0500
@@ -6360,6 +6360,7 @@
 	return;
     }
 
+#if 0
     if (iPtr->varFramePtr->isProcCallFrame & FRAME_IS_METHOD) {
 	CallContext *contextPtr = iPtr->varFramePtr->clientData;
 	Method *mPtr = contextPtr->callPtr->chain[contextPtr->index].mPtr;
@@ -6382,6 +6383,7 @@
 	    }
 	}
     }
+#endif
     Tcl_DeleteHashTable(&addedTable);
 }
 
_EOF_

# Further remove OO
cd generic

# Remove calls to TclOOInit()
sed 's@TclOOInit(interp)@TCL_OK@' tclBasic.c > tclBasic.c.new
cat tclBasic.c.new > tclBasic.c
rm -f tclBasic.c.new

# Rmove all TclOO* related compilation units, to be sure to catch all removals
for file in tclOO*.[ch]; do
	> "${file}"
done
