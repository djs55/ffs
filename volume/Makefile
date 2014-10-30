COMMANDS=Plugin.Query Plugin.diagnostics SR.create SR.ls SR.destroy SR.attach SR.detach Volume.create Volume.destroy Volume.stat Volume.snapshot Volume.clone
LIBRARIES=fs.ml qemu.ml common.ml

.PHONY: clean
clean:
	rm -f *.exe

.PHONY: test
test:
	# Running the commands will invoke the typechecker
	for command in $(COMMANDS); do \
	        echo $$command ; \
		./$$command --test ; \
	done

DESTDIR?=/
SCRIPTDIR?=/usr/lib/xapi-storage-script/volume/org.xen.xcp.storage.ffs

.PHONY: install
install:
	mkdir -p $(DESTDIR)$(SCRIPTDIR)
	install -m 0755 $(COMMANDS) $(DESTDIR)$(SCRIPTDIR)
	install -m 0644 $(LIBRARIES) $(DESTDIR)$(SCRIPTDIR)
