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

rm -rf tcl/patchscripts/

find . -name '.*.sw?' -type f | xargs rm -f
