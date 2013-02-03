BINDIR?=/tmp/

install:
	install -m 0755 dist/build/ffs/ffs ${BINDIR}

uninstall:
	rm -f ${BINDIR}/ffs
