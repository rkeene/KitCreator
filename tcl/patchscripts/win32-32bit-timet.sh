#! /usr/bin/env bash

(
	echo '#define _USE_32BIT_TIME_T 1'
	cat generic/tcl.h
) > generic/tcl.h.new
cat generic/tcl.h.new > generic/tcl.h

exit 0
