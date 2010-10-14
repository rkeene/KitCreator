#! /bin/bash

./kitcreator distclean

KITSHROOTDIR="$(ls -1d kitsh/buildsrc/kitsh-*/)"
export KITSHROOTDIR
(
	cd "${KITSHROOTDIR}" || exit 1

	autoconf; autoheader
	rm -rf autom4te.cache
	rm -f *~

	./configure || exit 1
	make boot.tcl.h
	make zipvfs.tcl.h

	make distclean
) || exit 1

KITDLLROOTDIR="$(ls -1d kitdll/buildsrc/kitdll-*/)"
export KITDLLROOTDIR
(
	cd "${KITDLLROOTDIR}" || exit 1

	autoconf; autoheader
	rm -rf autom4te.cache
	rm -f *~

	./configure || exit 1
	make vfs_kitdll.tcl.h || exit 1

	make distclean
) || exit 1

rm -f tcl/patchscripts/dietlibc.sh

find . -name '.*.sw?' -type f | xargs rm -f
