#!/usr/bin/env python

import os
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

# Use Xen tapdisk to create block devices from files

class Vhd:
    def __init__(self, path):
        self.path = path
    def __str__(self):
        return "vhd:" + self.path
class Raw:
    def __init__(self, path):
        self.path = path
    def __str__(self):
        return "aio:" + self.path

blktap2_prefix = "/dev/xen/blktap-2/tapdev"

class Tapdisk:
    def __init__(self, minor, pid, f):
        self.minor = minor
        self.pid = pid
        self.f = f
    def destroy(self, dbg):
        run(dbg, "tap-ctl detach -m %d -p %d" % (self.minor, self.pid))
        run(dbg, "tap-ctl free -m %d" % (self.minor))
    def close(self, dbg):
        run(dbg, "tap-ctl close -m %d -p %d" % (self.minor, self.pid))
        self.f = None
    def open(self, dbg, f):
        assert (isinstance(f, Vhd) or isinstance(f, Raw))
        run(dbg, "tap-ctl open -m %d -p %d -a %s" % (self.minor, self.pid, str(f)))
        self.f = f
    def block_device(self):
        return blktap2_prefix + str(self.minor)

def create(dbg):
    output = run(dbg, "tap-ctl spawn").strip()
    pid = int(output)
    output = run(dbg, "tap-ctl allocate").strip()
    prefix = blktap2_prefix
    minor = None
    if output.startswith(prefix):
        minor = int(output[len(prefix):])
    if minor is None:
        os.kill(pid, signal.SIGQUIT)
        raise (xapi.InternalError("tap-ctl allocate returned unexpected output: '%s'" % output))
    run(dbg, "tap-ctl attach -m %d -p %d" % (minor, pid))
    return Tapdisk(minor, pid, None)

def list(dbg):
    results = []
    for line in run(dbg, "tap-ctl list").split("\n"):
        bits = line.split()
        if bits == []:
            continue
        prefix = "pid="
        pid = None
        if bits[0].startswith(prefix):
            pid = int(bits[0][len(prefix):])
        minor = None
        prefix = "minor="
        if bits[1].startswith(prefix):
            minor = int(bits[1][len(prefix):])
        if len(bits) <= 3:
            results.append(Tapdisk(minor, pid, None))
        else:
            prefix = "args="
            args = None
            if bits[3].startswith(prefix):
                args = bits[3][len(prefix):]
                this = None
                prefix = "aio:"
                if args.startswith(prefix):
                    this = Raw(args[len(prefix):])
                    results.append(Tapdisk(minor, pid, this))
                prefix = "vhd:"
                if args.startswith(prefix):
                    this = Vhd(args[len(prefix):])
                    results.append(Tapdisk(minor, pid, this))
    return results

def find_by_file(dbg, f):
    assert (isinstance(f, Vhd) or isinstance(f, Raw))
    for tapdisk in list(dbg):
        if str(f) == str(tapdisk.f):
            return tapdisk
