DATAPATH_COMMANDS=Datapath.activate  Datapath.attach  Datapath.deactivate  Datapath.detach
VOLUME_COMMANDS=Plugin.Query Plugin.diagnostics SR.create SR.ls SR.destroy SR.attach SR.detach Volume.create Volume.destroy Volume.stat

.PHONY: clean
clean:

DESTDIR?=/
SCRIPTDIR?=/usr/libexec/xapi-storage-script

.PHONY: install
install:
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/datapath/raw+file
	(cd datapath/raw+file; install -m 0755 $(DATAPATH_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/datapath/raw+file)
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xcp.storage.ffs
	(cd volume/org.xen.xcp.storage.ffs; install -m 0755 $(VOLUME_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xcp.storage.ffs)
