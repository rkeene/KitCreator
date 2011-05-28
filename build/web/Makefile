STARKIT2EXE = ../../../starkit2exe/starkit2exe
RIVET2STARKIT = ../../../rivet/bin/rivet2starkit

kitcreator.cgi: kitcreator.kit
	$(STARKIT2EXE) kitcreator.kit kitcreator.cgi

kitcreator.kit: kitcreator.vfs kitcreator.vfs/index.rvt
	$(RIVET2STARKIT) tclkit kitcreator.kit kitcreator.vfs

clean:
	rm -f kitcreator.kit kitcreator.cgi

distclean: clean

.PHONY: clean distclean
