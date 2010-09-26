#define HAVE_STDC 1

#include <tcl.h>
#include <stdio.h>
#include <stdlib.h>

#include "vfs_kitdll_data.h"

typedef struct kitdll_data *(cmd_getData_t)(const char *, unsigned long);
typedef unsigned long (cmd_getChildren_t)(const char *, unsigned long *, unsigned long);

static cmd_getData_t *getCmdData(const char *hashkey) {
	/* XXX: TODO: Look up symbol using dlsym() */
	if (strcmp(hashkey, "vfs_kitdll_data") == 0) {
		return(kitdll_vfs_kitdll_data_getData);
	}

	return(NULL);
}

static cmd_getChildren_t *getCmdChildren(const char *hashkey) {
	/* XXX: TODO: Look up symbol using dlsym() */
	if (strcmp(hashkey, "vfs_kitdll_data") == 0) {
		return(kitdll_vfs_kitdll_data_getChildren);
	}

	return(NULL);
}

static int getMetadata(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	cmd_getData_t *cmd_getData;
	cmd_getChildren_t *cmd_getChildren;
	struct kitdll_data *finfo = NULL;
	Tcl_Obj *ret_list, *ret_list_items[20];
	unsigned long num_children;
	const char *hashkey;
	const char *file;

	if (objc != 3) {
		Tcl_SetResult(interp, "wrong # args: should be \"getMetadata hashKey fileName\"", TCL_STATIC);

		return(TCL_ERROR);
	}

	hashkey = Tcl_GetString(objv[1]);
	file = Tcl_GetString(objv[2]);

	cmd_getData = getCmdData(hashkey);
	cmd_getChildren = getCmdChildren(hashkey);

	if (cmd_getData == NULL || cmd_getChildren == NULL) {
		Tcl_SetResult(interp, "No such hashkey", TCL_STATIC);

		return(TCL_ERROR);
	}

	finfo = cmd_getData(file, 0);

	if (finfo == NULL) {
		Tcl_SetResult(interp, "No such file or directory", TCL_STATIC);

		return(TCL_ERROR);
	}

	/* Values that can be derived from "finfo" */
	ret_list_items[0] = Tcl_NewStringObj("type", 4);
	ret_list_items[2] = Tcl_NewStringObj("mode", 4);
	ret_list_items[4] = Tcl_NewStringObj("nlink", 5);

	if (finfo->type == KITDLL_FILETYPE_DIR) {
		num_children = cmd_getChildren(file, NULL, 0);

		ret_list_items[1] = Tcl_NewStringObj("directory", 9);
		ret_list_items[3] = Tcl_NewLongObj(040555);
		ret_list_items[5] = Tcl_NewLongObj(num_children);
	} else {
		ret_list_items[1] = Tcl_NewStringObj("file", 4);
		ret_list_items[3] = Tcl_NewLongObj(0444);
		ret_list_items[5] = Tcl_NewLongObj(1);
	}

	ret_list_items[6] = Tcl_NewStringObj("ino", 3);
	ret_list_items[7] = Tcl_NewLongObj(finfo->index);

	ret_list_items[8] = Tcl_NewStringObj("size", 4);
	ret_list_items[9] = Tcl_NewLongObj(finfo->size);

	/* Dummy values */
	ret_list_items[10] = Tcl_NewStringObj("uid", 3);
	ret_list_items[11] = Tcl_NewStringObj("0", 1);

	ret_list_items[12] = Tcl_NewStringObj("gid", 3);
	ret_list_items[13] = Tcl_NewStringObj("0", 1);

	ret_list_items[14] = Tcl_NewStringObj("atime", 5);
	ret_list_items[15] = Tcl_NewStringObj("0", 1);

	ret_list_items[16] = Tcl_NewStringObj("mtime", 5);
	ret_list_items[17] = Tcl_NewStringObj("0", 1);

	ret_list_items[18] = Tcl_NewStringObj("ctime", 5);
	ret_list_items[19] = Tcl_NewStringObj("0", 1);

	ret_list = Tcl_NewListObj(sizeof(ret_list_items) / sizeof(ret_list_items[0]), ret_list_items);

	Tcl_SetObjResult(interp, ret_list);

	return(TCL_OK);
}

static int getData(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	struct kitdll_data *finfo = NULL;
	cmd_getData_t *cmd_getData;
	const char *hashkey;
	const char *file;
	const char *end_str;
	Tcl_Obj *ret_str;
	long start = 0;
	long end = -1;
	int tclGetLFO_ret;

	if (objc < 3 || objc > 5) {
		Tcl_SetResult(interp, "wrong # args: should be \"getData hashKey fileName ?start? ?end?\"", TCL_STATIC);

		return(TCL_ERROR);
	}

	hashkey = Tcl_GetString(objv[1]);
	file = Tcl_GetString(objv[2]);

	if (objc > 3) {
		tclGetLFO_ret = Tcl_GetLongFromObj(interp, objv[3], &start);

		if (tclGetLFO_ret != TCL_OK) {
			return(tclGetLFO_ret);
		}
	}

	if (objc > 4) {
		end_str = Tcl_GetString(objv[4]);
		if (strcmp(end_str, "end") == 0) {
			end = -1;
		} else {
			tclGetLFO_ret = Tcl_GetLongFromObj(interp, objv[4], &end);

			if (tclGetLFO_ret != TCL_OK) {
				return(tclGetLFO_ret);
			}
		}
	}

	cmd_getData = getCmdData(hashkey);

	if (cmd_getData == NULL) {
		Tcl_SetResult(interp, "No such hashkey", TCL_STATIC);

		return(TCL_ERROR);
	}

	finfo = cmd_getData(file, 0);

	if (finfo == NULL) {
		Tcl_SetResult(interp, "No such file or directory", TCL_STATIC);

		return(TCL_ERROR);
	}

	if (finfo->type != KITDLL_FILETYPE_FILE) {
		Tcl_SetResult(interp, "Not a file", TCL_STATIC);

		return(TCL_ERROR);
	}

	if (end == -1) {
		end = finfo->size;
	}

	if (end > finfo->size) {
		end = finfo->size;
	}

	if (start < 0) {
		start = 0;
	}

	if (end < 0) {
		end = 0;
	}

	if (end < start) {
		Tcl_SetResult(interp, "Invalid arguments, start must be less than end", TCL_STATIC);

		return(TCL_ERROR);
	}

	ret_str = Tcl_NewStringObj((const char *) finfo->data + start, (end - start));

	Tcl_SetObjResult(interp, ret_str);

	return(TCL_OK);
}

static int getChildren(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	struct kitdll_data *finfo = NULL;
	cmd_getChildren_t *cmd_getChildren;
	cmd_getData_t *cmd_getData;
	unsigned long num_children, idx;
	unsigned long *children;
	const char *hashkey;
	const char *file;
	const char *child;
	Tcl_Obj *ret_list, *ret_curr_obj;

	if (objc != 3) {
		Tcl_SetResult(interp, "wrong # args: should be \"getChildren hashKey fileName\"", TCL_STATIC);

		return(TCL_ERROR);
	}

	hashkey = Tcl_GetString(objv[1]);
	file = Tcl_GetString(objv[2]);

	cmd_getData = getCmdData(hashkey);
	cmd_getChildren = getCmdChildren(hashkey);

	if (cmd_getData == NULL || cmd_getChildren == NULL) {
		Tcl_SetResult(interp, "No such hashkey", TCL_STATIC);

		return(TCL_ERROR);
	}

	finfo = cmd_getData(file, 0);

	if (finfo == NULL) {
		Tcl_SetResult(interp, "No such file or directory", TCL_STATIC);

		return(TCL_ERROR);
	}

	if (finfo->type != KITDLL_FILETYPE_DIR) {
		Tcl_SetResult(interp, "Not a directory", TCL_STATIC);

		return(TCL_ERROR);
	}

	num_children = cmd_getChildren(file, NULL, 0);

	if (num_children == 0) {
		/* Return immediately if there are no children */
		Tcl_SetResult(interp, "", TCL_STATIC);

		return(TCL_OK);
	}

	ret_list = Tcl_NewObj();
	if (ret_list == NULL) {
		Tcl_SetResult(interp, "Failed to allocate new object", TCL_STATIC);

		return(TCL_ERROR);
	}

	children = malloc(sizeof(*children) * num_children);

	num_children = cmd_getChildren(file, children, num_children);

	for (idx = 0; idx < num_children; idx++) {
		finfo = cmd_getData(NULL, children[idx]);

		if (finfo == NULL || finfo->name == NULL) {
			continue;
		}

		child = finfo->name;

		ret_curr_obj = Tcl_NewStringObj(child, strlen(child));

		Tcl_ListObjAppendList(interp, ret_list, ret_curr_obj);
	}

	free(children);

	Tcl_SetObjResult(interp, ret_list);

	return(TCL_OK);
}

int Vfs_kitdll_data_Init(Tcl_Interp *interp) {   
	Tcl_Command tclCreatComm_ret;
	int tclPkgProv_ret;

	tclCreatComm_ret = Tcl_CreateObjCommand(interp, "::vfs::kitdll::data::getMetadata", getMetadata, NULL, NULL);
	if (!tclCreatComm_ret) {
		return(TCL_ERROR);
	}

	tclCreatComm_ret = Tcl_CreateObjCommand(interp, "::vfs::kitdll::data::getData", getData, NULL, NULL);
	if (!tclCreatComm_ret) {
		return(TCL_ERROR);
	}

	tclCreatComm_ret = Tcl_CreateObjCommand(interp, "::vfs::kitdll::data::getChildren", getChildren, NULL, NULL);
	if (!tclCreatComm_ret) {
		return(TCL_ERROR);
	}

	tclPkgProv_ret = Tcl_PkgProvide(interp, "vfs::kitdll::data", "1.0");

	return(tclPkgProv_ret);
}
