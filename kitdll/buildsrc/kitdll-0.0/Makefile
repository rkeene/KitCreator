CC = gcc
CFLAGS = -Wall -O3
CPPFLAGS = -DUSE_TCL_STUBS
LIBS = -ltclstub8.5

all: vfs_kitdll_data.so

vfs_kitdll_data.h: dir2c.tcl starpack.vfs
	./dir2c.tcl vfs_kitdll_data starpack.vfs > vfs_kitdll_data.h

vfs_kitdll.tcl.h: vfs_kitdll.tcl
	./stringify.tcl vfs_kitdll.tcl > vfs_kitdll.tcl.h

vfs_kitdll_data.o: vfs_kitdll_data.c vfs_kitdll_data.h vfs_kitdll.tcl.h

vfs_kitdll_data.so: vfs_kitdll_data.o
	$(CC) $(CPPFLAGS) $(CFLAGS) -rdynamic -shared $(LDFLAGS) -o vfs_kitdll_data.so vfs_kitdll_data.o $(LIBS)

clean:
	rm -f vfs_kitdll_data.so vfs_kitdll_data.o
	rm -f vfs_kitdll.tcl.h vfs_kitdll_data.h

.PHONY: clean
