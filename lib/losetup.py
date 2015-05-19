#!/usr/bin/env python

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

# Use Linux "losetup" to create block devices from files

class Loop:
    """An active loop device"""
    def __init__(self, path, loop):
        self.path = path
        self.loop = loop
    def destroy(self, dbg):
        run(dbg, "losetup -d %s" % self.loop)
    def block_device(self):
        return self.loop

def find(dbg, path):
    """Return the active loop device associated with the given path"""
    for line in run(dbg, "losetup -a").split("\n"):
        line = line.strip()
        if line <> "":
            bits = line.split()
            loop = bits[0][0:-1]
            this_path = bits[2][1:-1]
            if this_path == path:
                return Loop(path, loop)
    return None

def create(dbg, path):
    """Creates a new loop device backed by the given file"""
    run(dbg, "losetup -f %s" % path)
    return find(dbg, path)

