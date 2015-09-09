#!/usr/bin/env python

import json
import errno
import urlparse
import os
import os.path
import stat
import subprocess
import sys
import xapi
import xapi.volume
from common import mountpoint_root
from ffs import log


def get_mountpoint(attach_uri):
    """Given a URI pointing at the storage, return the local mountpoint
       that we will use when attaching this SR."""
    u = urlparse.urlparse(attach_uri)
    return os.path.abspath(mountpoint_root + u.path)


class Implementation(xapi.volume.SR_skeleton):

    def probe(self, dbg, uri):
        u = urlparse.urlparse(uri)
        srs = []
        try:
            # XXX: increase reference count of filesystem
            mountpoint = get_mountpoint(uri)
            attached_uri = "file://" + mountpoint
            need_to_mount = not os.path.ismount(mountpoint)
            if need_to_mount:
                attached_uri = self.attach(dbg, uri)
            srs.append(self.stat(dbg, attached_uri))
            if need_to_mount:
                self.detach(dbg, attached_uri)
            # XXX: decrease reference count of filesystem
        except:
            pass
        uris = []
        if os.path.isdir(u.path):
            for child in os.listdir(u.path):
                path = os.path.join(u.path, child)
                mode = os.stat(path).st_mode
                if stat.S_ISDIR(mode) or stat.S_ISBLK(mode):
                    uris.append("file://" + path)
        return {
            'srs': srs,
            'uris': uris,
        }

    def attach(self, dbg, uri):
        u = urlparse.urlparse(uri)
        # u.path is the path to the block device
        mountpoint = get_mountpoint(uri)
        try:
            os.makedirs(mountpoint)
        except OSError as exc:
            if exc.errno == errno.EEXIST and os.path.isdir(mountpoint):
                pass
            else:
                raise
        if not os.path.ismount(mountpoint):
            code = subprocess.call(["mount", "-t", "btrfs", u.path,
                                    mountpoint])
            if code != 0:
                raise xapi.volume.Unimplemented(
                    "mount -t btrfs %s %s failed" % (u.path, mountpoint))
        uri = "file://" + mountpoint
        return uri

    def stat(self, dbg, sr):
        u = urlparse.urlparse(sr)
        statvfs = os.statvfs(u.path)
        physical_size = statvfs.f_blocks * statvfs.f_frsize
        free_size = statvfs.f_bfree * statvfs.f_frsize
        return {
            "sr": sr,
            "name": "This SR has no name",
            "description": "This SR has no description",
            "total_space": physical_size,
            "free_space": free_size,
            "datasources": [],
            "clustered": False,
            "health": ["Healthy", ""]
        }

    def create(self, dbg, uri, name, description, configuration):
        u = urlparse.urlparse(uri)
        # sometimes a user can believe that a device exists because
        # they've just created it, but they don't realise that the actual
        # device will be created by a queued udev event. Make the client's
        # life easier by waiting for outstanding udev events to complete.
        code = subprocess.call(["udevadm", "settle"])
        # if that fails then log and continue
        if code != 0:
            log.info("udevadm settle exitted with code %d" % code)

        p = subprocess.Popen(["mkfs.btrfs",
                              u.path,
                              "-f"],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
            raise xapi.volume.Unimplemented("mkfs.btrfs failed on %s" % u.path)
        local_uri = self.attach(dbg, uri)
        with open(urlparse.urlparse(local_uri).path + "/.json", "w") as fd:
            meta = {
                "name": name,
                "description": description
            }
            json.dump(meta, fd)
            fd.write("\n")
        self.detach(dbg, local_uri)
        return

    def set_name(self, dbg, sr, name):
        path = urlparse.urlparse(sr).path
        meta = {}
        with open(path + "/.json", "r") as fd:
            meta = json.load(fd)
        meta["name"] = name
        with open(path + "/.json", "w") as fd:
            json.dump(meta, fd)
            fd.write("\n")
        return

    def set_description(self, dbg, sr, description):
        path = urlparse.urlparse(sr).path
        meta = {}
        with open(path + "/.json", "r") as fd:
            meta = json.load(fd)
        meta["description"] = description
        with open(path + "/.json", "w") as fd:
            json.dump(meta, fd)
            fd.write("\n")
        return

    def destroy(self, dbg, sr):
        # no need to destroy anything
        return

    def detach(self, dbg, sr):
        u = urlparse.urlparse(sr)
        code = subprocess.call(["umount", u.path])
        if code != 0:
            raise xapi.XenAPIException("DAVE", ["IS", "COOL"])
        return

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.volume.SR_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    try:
        if base == "SR.probe":
            cmd.probe()
        elif base == "SR.stat":
            cmd.stat()
        elif base == "SR.attach":
            cmd.attach()
        elif base == "SR.create":
            cmd.create()
        elif base == "SR.set_name":
            cmd.set_name()
        elif base == "SR.set_description":
            cmd.set_description()
        elif base == "SR.destroy":
            cmd.destroy()
        elif base == "SR.detach":
            cmd.detach()
        else:
            raise xapi.volume.Unimplemented(base)
    except Exception, e:
        xapi.handle_exception(e)
