#! /bin/bash

sed 's/define EXTERN .*/define EXTERN/' generic/tcl.h > generic/tcl.h.new
cat generic/tcl.h.new > generic/tcl.h
rm -f generic/tcl.h.new
