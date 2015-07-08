#!/usr/bin/env python

import sys, urlparse, os, os.path
import xapi, xapi.volume

class Implementation(xapi.volume.SR_skeleton):
    def ls(self, dbg, sr):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.volume.Sr_not_attached(sr)
        results = []
        for filename in os.listdir(u.path):
            path = os.path.join(u.path, filename)
            stat = os.stat(path)
            virtual_size = stat.st_size
            physical_utilisation = stat.st_blocks*512
            results.append({
                "key": filename,
                "name": filename,
                "description": "",
                "read_write": True,
                "virtual_size": virtual_size,
                "physical_utilisation": physical_utilisation,
                "uri": ["raw+file:///" + path]
            })
        return results

if __name__ == "__main__":
    cmd = xapi.volume.SR_commandline(Implementation())
    cmd.ls()
