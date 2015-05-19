#!/usr/bin/env python

import os
import sys
import signal
import xapi
import commands

def log(txt):
    print >>sys.stderr, txt

# [run dbg cmd] executes [cmd], throwing a BackendError if exits with
# a non-zero exit code.
def run(dbg, cmd):
    code, output = commands.getstatusoutput(cmd)
    if code <> 0:
        log("%s: %s exitted with code %d: %s" % (dbg, cmd, code, output))
        raise (xapi.InternalError("%s exitted with non-zero code %d: %s" % (cmd, code, output)))
    return output
