#!/usr/bin/env python

import sys, urlparse
import xapi, xapi.volume

class Implementation(xapi.volume.SR_skeleton):
    def ls(self, dbg, sr):
        u = urlparse.urlparse(sr)
        return [ {
            "key": "unknown-volume",
            "name": "unknown-volume",
            "description": "",
            "read_write": True,
            "virtual_size": 1,
            "uri": ["file:\/\/\/secondary\/sr\/unknown-volume"]
        } ]

if __name__ == "__main__":
    cmd = xapi.volume.SR_commandline(Implementation())
    cmd.ls()
