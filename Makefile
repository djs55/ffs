BINDIR?=/tmp/

dist/build/ffs/ffs:
	obuild configure
	obuild build

install:
	install -m 0755 dist/build/ffs/ffs ${BINDIR}

uninstall:
	rm -f ${BINDIR}/ffs

.PHONY: clean
clean:
	rm -rf dist
