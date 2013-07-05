#! /usr/bin/env bash

# Do not run on Win32
if echo '_WIN64' | x86_64-w64-mingw32-gcc -E - | grep '^_WIN64$'; then
	(
		echo '#ifndef _USE_32BIT_TIME_T'
		echo '#define _USE_32BIT_TIME_T 1'
		echo '#endif'
		cat generic/tcl.h
	) > generic/tcl.h.new
	cat generic/tcl.h.new > generic/tcl.h
fi

exit 0
