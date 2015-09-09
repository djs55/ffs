#!/usr/bin/env python

from common import mountpoint_root
import errno
import urlparse
import os
import os.path
import subprocess
import sys
import xapi
import xapi.volume
from ffs import log


class Implementation(xapi.volume.SR_skeleton):

    def probe(self, dbg, uri):
        raise AssertionError("not implemented")

    def attach(self, dbg, uri):
        u = urlparse.urlparse(uri)
        mountpoint = mountpoint_root + "/" + u.netloc + "/" + u.path
        try:
            os.makedirs(mountpoint)
        except OSError as exc:
            if exc.errno == errno.EEXIST and os.path.isdir(mountpoint):
                pass
            else:
                raise
        if not os.path.ismount(mountpoint):
            cmd = ["mount", "-t", "nfs",
                   "-o", "acdirmin=0,acdirmax=0",
                   u.netloc + ":" + u.path, mountpoint]
            code = subprocess.call(cmd)
            if code != 0:
                raise xapi.volume.Unimplemented(" ".join(cmd) + " failed")
        uri = "file://" + mountpoint
        return uri

    def create(self, dbg, uri, name, description, configuration):
        u = urlparse.urlparse(uri)
        if (u.scheme != "nfs" or not u.netloc or not u.path):
            raise xapi.volume.SR_does_not_exist(
                "The SR URI %s is invalid. " % (uri) +
                "Please provide the URI as nfs://<host><path>"
            )
        return

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.volume.SR_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    if base == "SR.probe":
        cmd.probe()
    elif base == "SR.attach":
        cmd.attach()
    elif base == "SR.create":
        cmd.create()
    else:
        xapi.volume.Unimplemented(base)
