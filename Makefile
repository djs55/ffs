TAPDISK_COMMANDS=Plugin.Query Datapath.activate Datapath.attach Datapath.deactivate Datapath.detach Datapath.open Datapath.close
LOOP_COMMANDS=Plugin.Query Datapath.activate  Datapath.attach  Datapath.deactivate  Datapath.detach
FFS_COMMANDS=plugin.py Plugin.Query Plugin.diagnostics sr.py SR.probe SR.create SR.ls SR.destroy SR.attach SR.detach SR.stat volume.py Volume.create Volume.destroy Volume.stat Volume.clone Volume.snapshot Volume.resize Volume.set_name Volume.set_description Volume.set Volume.unset
BTRFS_COMMANDS=plugin.py Plugin.Query Plugin.diagnostics sr.py SR.probe SR.create SR.set_name SR.set_description SR.ls SR.destroy SR.attach SR.detach SR.stat Volume.create Volume.destroy Volume.stat Volume.clone Volume.snapshot Volume.resize common.py Volume.set_name Volume.set_description Volume.set Volume.unset
RAWNFS_COMMANDS=plugin.py Plugin.Query Plugin.diagnostics sr.py SR.create SR.ls SR.destroy SR.attach SR.detach SR.stat Volume.create Volume.destroy Volume.stat Volume.clone Volume.snapshot Volume.resize common.py Volume.set_name Volume.set_description Volume.set Volume.unset
LIB_FILES=ffs/__init__.py ffs/losetup.py ffs/tapdisk.py ffs/dmsetup.py ffs/nbdclient.py ffs/nbdtool.py ffs/image.py ffs/common.py ffs/poolhelper.py ffs/log.py

.PHONY: clean
clean:

DESTDIR?=/
SCRIPTDIR?=/usr/libexec/xapi-storage-script
PYTHONDIR?=/usr/lib/python2.7/site-packages/ffs
XAPIPLUGINDIR?=/etc/xapi.d/plugins/

.PHONY: install
install:
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/datapath/loop+blkback
	(cd datapath/loop+blkback; install -m 0755 $(LOOP_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/datapath/loop+blkback)
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/datapath/tapdisk
	(cd datapath/tapdisk; install -m 0755 $(TAPDISK_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/datapath/tapdisk)
	(cd $(DESTDIR)$(SCRIPTDIR)/datapath ; ln -snf tapdisk raw+file ; ln -snf tapdisk vhd+file)
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xapi.storage.ffs
	(cd volume/org.xen.xapi.storage.ffs; install -m 0755 $(FFS_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xapi.storage.ffs)
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xapi.storage.btrfs
	(cd volume/org.xen.xapi.storage.btrfs; install -m 0755 $(BTRFS_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xapi.storage.btrfs)
	mkdir -p $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xapi.storage.rawnfs
	(cd volume/org.xen.xapi.storage.rawnfs; install -m 0755 $(RAWNFS_COMMANDS) $(DESTDIR)$(SCRIPTDIR)/volume/org.xen.xapi.storage.rawnfs)
	mkdir -p $(DESTDIR)$(PYTHONDIR)
	(cd lib; install -m 0755 $(LIB_FILES) $(DESTDIR)$(PYTHONDIR)/)
	mkdir -p $(DESTDIR)$(XAPIPLUGINDIR)
	install -m 0755 overlay/$(XAPIPLUGINDIR)/ffs $(DESTDIR)$(XAPIPLUGINDIR)/ffs
