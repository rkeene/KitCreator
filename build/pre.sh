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
	make mk4tcl.tcl.h

	make distclean
) || exit 1

find . -name '.*.sw?' -type f | xargs rm -f
