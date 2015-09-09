#!/usr/bin/env python

import os
import sys
import xapi
import xapi.plugin
from ffs import log


class Implementation(xapi.plugin.Plugin_skeleton):

    def query(self, dbg):
        return {
            "plugin": "loopdev+blkback",
            "name": "The loopdev+blkback kernel-space datapath plugin",
            "description": ("This plugin manages and configures loop"
                            " devices which can be connected to VMs"
                            " directly via kernel-space blkback"),
            "vendor": "Citrix",
            "copyright": "(C) 2015 Citrix Inc",
            "version": "3.0",
            "required_api_version": "3.0",
            "features": [
            ],
            "configuration": {},
            "required_cluster_stack": []}

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.plugin.Plugin_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    if base == "Plugin.Query":
        cmd.query()
    else:
        raise xapi.plugin.Unimplemented(base)
