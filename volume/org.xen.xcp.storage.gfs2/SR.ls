#!/usr/bin/env python

import sys, urlparse, os, os.path
import xapi, xapi.volume
from xapi.common import call

class Implementation(xapi.volume.SR_skeleton):
    def ls(self, dbg, sr):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.volume.Sr_not_attached(sr)
        results = []
        for filename in os.listdir(u.path):
            path = os.path.join(u.path, filename)
            if filename[-4:] == ".vhd":
                type = "vhd"
                cmd = ["/usr/bin/vhd-util", "query", "-n", path, "-v"]
                stdout = call(dbg, cmd)
                size = str(int(stdout)*1048576)
            else:
                type = "raw+file"
                stat = os.stat(path)
                size = stat.st_size

            results.append({
                "key": filename,
                "name": filename,
                "description": "",
                "read_write": True,
                "virtual_size": size,
                "uri": [("%s:///" % type) + path]
            })
        return results

if __name__ == "__main__":
    cmd = xapi.volume.SR_commandline(Implementation())
    cmd.ls()
