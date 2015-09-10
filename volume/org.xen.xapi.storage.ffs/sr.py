#!/usr/bin/env python

import json
import os
import os.path
import sys
import urlparse
import xapi.storage.api.volume
from xapi.storage import log


class Implementation(xapi.storage.api.volume.SR_skeleton):

    def probe(self, dbg, uri):
        raise AssertionError("not implemented")

    def attach(self, dbg, uri):
        urlparse.urlparse(uri)
        # mount the filesystem if necessary
        return uri

    def create(self, dbg, uri, name, description, configuration):
        urlparse.urlparse(uri)
        # this would be a good place to run mkfs
        return

    def destroy(self, dbg, sr):
        # no need to destroy anything
        return

    def detach(self, dbg, sr):
        # assume there is no need to unmount the filesystem
        return

    def ls(self, dbg, sr):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        results = []
        for filename in os.listdir(u.path):
            if filename.endswith(".json"):
                continue
            path = os.path.join(u.path, filename)
            if not(os.path.isfile(os.path.realpath(path))):
                continue
            uuid_ = None
            name = filename
            description = filename
            keys = {}
            if os.path.exists(path + ".json"):
                with open(path + ".json", "r") as fd:
                    js = json.load(fd)
                    uuid_ = js["uuid"]
                    name = js["name"]
                    description = js["description"]
                    keys = js["keys"]
            stat = os.stat(path)
            virtual_size = stat.st_size
            physical_utilisation = stat.st_blocks * 512
            results.append({
                "key": filename,
                "uuid": uuid_,
                "name": name,
                "description": description,
                "read_write": True,
                "virtual_size": virtual_size,
                "physical_utilisation": physical_utilisation,
                "uri": ["raw+file:///" + path],
                "keys": keys
            })
        return results

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

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.storage.api.volume.SR_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    if base == 'SR.probe':
        cmd.probe()
    elif base == 'SR.attach':
        cmd.attach()
    elif base == 'SR.create':
        cmd.create()
    elif base == 'SR.destroy':
        cmd.destroy()
    elif base == 'SR.detach':
        cmd.detach()
    elif base == 'SR.ls':
        cmd.ls()
    elif base == 'SR.stat':
        cmd.stat()
    else:
        raise xapi.storage.api.volume.Unimplemented(base)
