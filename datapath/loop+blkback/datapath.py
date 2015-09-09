#!/usr/bin/env python

import urlparse
import os
import sys
import xapi
import xapi.datapath
from ffs import losetup, dmsetup
from ffs import log


class Implementation(xapi.datapath.Datapath_skeleton):

    def activate(self, dbg, uri, domain):
        return

    def attach(self, dbg, uri, domain):
        u = urlparse.urlparse(uri)
        # XXX need a datapath-specific error
        if not(os.path.exists(u.path)):
            raise xapi.volume.Volume_does_not_exist(u.path)
        loop = losetup.create(dbg, u.path)
        dm = dmsetup.create(dbg, loop.block_device())
        return {
            'domain_uuid': '0',
            'implementation': ['Blkback', dm.block_device()],
        }

    def deactivate(self, dbg, uri, domain):
        return

    def detach(self, dbg, uri, domain):
        u = urlparse.urlparse(uri)
        # XXX need a datapath-specific error
        if not(os.path.exists(u.path)):
            raise xapi.volume.Volume_does_not_exist(u.path)
        loop = losetup.find(dbg, u.path)
        dm = dmsetup.find(dbg, loop.block_device())
        dm.destroy(dbg)
        loop.destroy(dbg)

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.datapath.Datapath_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    if base == "Datapath.activate":
        cmd.activate()
    elif base == "Datapath.attach":
        cmd.attach()
    elif base == "Datapath.deactivate":
        cmd.deactivate()
    elif base == "Datapath.detach":
        cmd.detach()
    else:
        raise xapi.datapath.Unimplemented(base)
