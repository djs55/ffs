#!/usr/bin/env python

import os, sys, signal, socket, subprocess

"""
import tapdisk

# to create a block device
t = tapdisk.create()
t.open(tapdisk.Raw("foo.img"))
print t.block_device()

# to shut down
t.destroy()
"""

# Use Xen tapdisk to create block devices from files

blktap2_prefix = "/dev/xen/blktap-2/tapdev"

def log(txt):
    print >>sys.stderr, txt

# [call cmd_args] executes [cmd_args], throwing a BackendError if exits with
# a non-zero exit code.
def call(cmd_args):
    p = subprocess.Popen(cmd_args, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
    stdout, stderr = p.communicate ()
    if p.returncode <> 0:
        log("%s exitted with code %d: %s" % (" ".join(cmd_args), p.returncode, stderr))
        raise (Exception("%s exitted with non-zero code %d: %s" % (" ".join(cmd_args), p.returncode, stderr)))
    return stdout

class Path:
    """An entity on the filesystem"""
    def __init__(self, path):
        self.path = path

class Vhd(Path):
    """An entity on the filesystem in vhd format"""
    def __init__(self, path):
        Path.__init__(self, path)
    def format(self):
        return "vhd"
    def __str__(self):
        return "vhd:" + self.path

class Raw(Path):
    """An entity on the filesystem in raw format"""
    def __init__(self, path):
        Path.__init__(self, path)
    def format(self):
        return "raw"
    def __str__(self):
        return "aio:" + self.path

class Tapdisk:
    def __init__(self, minor, pid, f):
        self.minor = minor
        self.pid = pid
        self.f = f
        self.secondary = None # mirror destination
    def destroy(self):
        self.pause()
        call(["tap-ctl", "destroy", "-m", str(self.minor), "-p", str(self.pid) ])
    def close(self ):
        call(["tap-ctl", "close", "-m", str(self.minor), "-p", str(self.pid) ])
        self.f = None
    def open(self, f):
        assert (isinstance(f, Vhd) or isinstance(f, Raw))
        call(["tap-ctl", "open", "-m", str(self.minor), "-p", str(self.pid), "-a", str(f)])
        self.f = f
    def pause(self):
        call(["tap-ctl", "pause", "-m", str(self.minor), "-p", str(self.pid)])
    def unpause(self):
        cmd = ["tap-ctl", "unpause", "-m", str(self.minor), "-p", str(self.pid) ]
        if self.secondary is not None:
            cmd = cmd + [ "-2 ", self.secondary ]
        call(cmd)
    def block_device(self):
        return blktap2_prefix + str(self.minor)

def create():
    output = call(["tap-ctl", "spawn"]).strip()
    pid = int(output)
    output = call(["tap-ctl", "allocate"]).strip()
    prefix = blktap2_prefix
    minor = None
    if output.startswith(prefix):
        minor = int(output[len(prefix):])
    if minor is None:
        os.kill(pid, signal.SIGQUIT)
        raise (xapi.InternalError("tap-ctl allocate returned unexpected output: '%s'" % output))
    call( ["tap-ctl", "attach", "-m", str(minor), "-p", str(pid) ])
    return Tapdisk(minor, pid, None)

def list():
    results = []
    for line in call(["tap-ctl", "list"]).split("\n"):
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

def find_by_file(f):
    assert (isinstance(f, Vhd) or isinstance(f, Raw))
    for tapdisk in list():
        if str(f) == str(tapdisk.f):
            return tapdisk
