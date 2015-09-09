#!/usr/bin/env python

import os
import sys
import xapi
import xapi.plugin
from ffs import log


class Implementation(xapi.plugin.Plugin_skeleton):

    def query(self, dbg):
        return {
            "plugin": "tapdisk",
            "name": "The tapdisk user-space datapath plugin",
            "description": ("This plugin manages and configures tapdisk"
                            " instances backend by either raw or vhd"
                            " format files"),
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
