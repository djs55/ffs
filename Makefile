DESTDIR?=/tmp
SBINDIR?=/sbin
MANDIR?=/usr/share/man

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
	mv main.native ffs
	./ffs --help=groff > ffs.1

version.ml: VERSION
	echo "let version = \"$(shell cat VERSION)\"" > version.ml

install:
	mkdir -p $(DESTDIR)/$(SBINDIR)
	install ./ffs $(DESTDIR)/$(SBINDIR)/ffs
	mkdir -p $(DESTDIR)/$(MANDIR)/man1
	install ./ffs.1 $(DESTDIR)/$(MANDIR)/man1/ffs.1

reinstall: install

uninstall:
	rm -f $(DESTDIR)/$(SBINDIR)/ffs
	rm -f $(DESTDIR)/$(MANDIR)/man1/ffs.1
