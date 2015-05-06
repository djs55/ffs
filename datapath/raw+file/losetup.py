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
class Losetup:
    # [_find dbg path] returns the loop device associated with [path]
    def _find(self, dbg, path):
        for line in run(dbg, "losetup -a").split("\n"):
            line = line.strip()
            if line <> "":
                bits = line.split()
                loop = bits[0][0:-1]
                this_path = bits[2][1:-1]
                if this_path == path:
                    return loop
        return None
    # [add dbg path] creates a new loop device for [path] and returns it
    def add(self, dbg, path):
        run(dbg, "losetup -f %s" % path)
        return self._find(dbg, path)
    # [remove dbg path] removes the loop device associated with [path]
    def remove(self, dbg, path):
        loop = self._find(dbg, path)
        run(dbg, "losetup -d %s" % loop)

