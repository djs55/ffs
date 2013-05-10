BINDIR?=/tmp/

.PHONY: build install uninstall clean

build: configure.done
	obuild build

configure.done: ffs.obuild
	obuild configure
	touch configure.done

install:
	install -m 0755 dist/build/ffs/ffs ${BINDIR}

uninstall:
	rm -f ${BINDIR}/ffs

clean:
	rm -rf dist configure.done
