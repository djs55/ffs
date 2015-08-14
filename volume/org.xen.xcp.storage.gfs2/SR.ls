#!/usr/bin/env python

import urlparse
import os
import os.path
import json
import xapi
import xapi.volume
from xapi.common import call


class Implementation(xapi.volume.SR_skeleton):

    def ls(self, dbg, sr):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.volume.Sr_not_attached(sr)
        results = []
        for filename in os.listdir(u.path):
            # Skip json entries
            if filename.endswith(".json"):
                continue

            # Skip non-file entries
            path = os.path.join(u.path, filename)
            if not(os.path.isfile(os.path.realpath(path))):
                continue

            # Defaults
            name = filename
            description = filename
            keys = {}

            # Determine VDI type by extension
            if filename.endswith(".vhd"):
                type = "vhd+file"
                cmd = ["/usr/bin/vhd-util", "query", "-n", path, "-v"]
                stdout = call(dbg, cmd) # Returned in megabytes
                vsize = str(int(stdout) * 1048576)
                cmd = ["/usr/bin/vhd-util", "query", "-n", path, "-s"]
                stdout = call(dbg, cmd)
                psize = stdout          # Returned in bytes already
            else:
                type = "raw+file"
                stat = os.stat(path)
                vsize = stat.st_size
                psize = vsize

            # Attempt to open the json metadata
            if os.path.exists(path + ".json"):
                with open(path + ".json", "r") as fd:
                    js = json.load(fd)
                    name = js["name"]
                    description = js["description"]
                    keys = js["keys"]

            results.append({
                "key": filename,
                "name": name,
                "description": description,
                "read_write": True,
                "virtual_size": vsize,
                "physical_utilisation": psize,
                "uri": [("%s:///" % type) + path],
                "keys": keys
            })
        return results

if __name__ == "__main__":
    cmd = xapi.volume.SR_commandline(Implementation())
    cmd.ls()
