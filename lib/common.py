#!/usr/bin/env python

import os
import sys
import signal
import xapi
import commands
import subprocess

def log(txt):
    print >>sys.stderr, txt

# [call dbg cmd_args] executes [cmd_args], throwing a BackendError if exits with
# a non-zero exit code.
def call(dbg, cmd_args):
    p = subprocess.Popen(cmd_args, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
    stdout, stderr = p.communicate ()
    if p.returncode <> 0:
        log("%s: %s exitted with code %d: %s" % (dbg, cmd, p.returncode, stderr))
        raise (xapi.InternalError("%s exitted with non-zero code %d: %s" % (cmd, p.returncode, stderr)))
    return stdout
