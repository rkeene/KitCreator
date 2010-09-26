#! /bin/bash

./kitcreator distclean

KITSHROOTDIR="$(ls -1d kitsh/buildsrc/kitsh-*/)"
export KITSHROOTDIR

(
	cd "${KITSHROOTDIR}" || exit 1

	autoconf; autoheader
	rm -rf autom4te.cache

	./configure

	make distclean
)
