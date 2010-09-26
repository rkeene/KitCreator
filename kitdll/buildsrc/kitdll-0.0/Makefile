CC = gcc
CFLAGS = -Wall -O3
CPPFLAGS = -DUSE_TCL_STUBS -DKITDLL_MAKE_LOADABLE=1 -DHAVE_STDC=1
LIBS = -ltclstub8.5

all: vfs_kitdll_data_tcl.so

vfs_kitdll_data_tcl.c: dir2c.tcl starpack.vfs vfs_kitdll_data.c
	./dir2c.tcl tcl starpack.vfs > vfs_kitdll_data_tcl.c

vfs_kitdll.tcl.h: vfs_kitdll.tcl
	./stringify.tcl vfs_kitdll.tcl > vfs_kitdll.tcl.h

vfs_kitdll_data_tcl.o: vfs_kitdll_data_tcl.c

vfs_kitdll_data_tcl.so: vfs_kitdll_data_tcl.o
	$(CC) $(CPPFLAGS) $(CFLAGS) -rdynamic -shared $(LDFLAGS) -o vfs_kitdll_data_tcl.so vfs_kitdll_data_tcl.o $(LIBS)

clean:
	rm -f vfs_kitdll_data_tcl.so vfs_kitdll_data_tcl.o
	rm -f vfs_kitdll_data_tcl.c

.PHONY: clean
