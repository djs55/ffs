.PHONY: all clean install build reinstall uninstall distclean
all: build

clean:
	@rm -f setup.data setup.log setup.bin config.mk version.ml
	@rm -rf _build
	@rm -f *.native

setup.bin: setup.ml
	@ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	@rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	@./setup.bin -configure

build: setup.data setup.bin version.ml
	@./setup.bin -build 

version.ml: VERSION
	echo "let version = \"$(shell cat VERSION)\"" > version.ml

install:
	mkdir -p $(DESTDIR)/$(SBINDIR)
	install ./main.native $(DESTDIR)/$(SBINDIR)/ffs

reinstall: install

uninstall:
	rm -f $(DESTDIR)/$(SBINDIR)/ffs

