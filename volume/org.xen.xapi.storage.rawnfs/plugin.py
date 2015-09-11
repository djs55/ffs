#!/usr/bin/env python

import os
import sys
import xapi
import xapi.storage.api.plugin
from xapi.storage import log


class Implementation(xapi.storage.api.plugin.Plugin_skeleton):

    def query(self, dbg):
        return {
            "plugin": "rawnfs",
            "name": "NFS Raw Volume plugin",
            "description": ("This plugin attaches a remote NFS and puts "
                            "raw files onto it."),
            "vendor": "None",
            "copyright": "(C) 2016 Citrix Inc",
            "version": "3.0",
            "required_api_version": "3.0",
            "features": [
                "SR_ATTACH",
                "SR_DETACH",
                "SR_CREATE",
                "SR_METADATA",
                "VDI_CREATE",
                "VDI_DESTROY",
                "VDI_ATTACH",
                "VDI_ATTACH_OFFLINE",
                "VDI_DETACH",
                "VDI_ACTIVATE",
                "VDI_DEACTIVATE"
                "VDI_RESIZE",
                "VDI_CLONE",
                "VDI_SNAPSHOT"],
            "configuration": {},
            "required_cluster_stack": []}

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.storage.api.plugin.Plugin_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    if base == "Plugin.Query":
        cmd.query()
    else:
        xapi.storage.api.plugin.Unimplemented(base)
