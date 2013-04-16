BINDIR?=/tmp/

.PHONY: build
build: configure.done
	obuild build

configure.done: ffs.obuild
	obuild configure
	touch configure.done

install:
	install -m 0755 dist/build/ffs/ffs ${BINDIR}

uninstall:
	rm -f ${BINDIR}/ffs

.PHONY: clean
clean:
	rm -rf dist
