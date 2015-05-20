#!/usr/bin/env python

import os
import signal
import socket

# from python-fdsend
import fdsend

import xapi
import commands
import image
from common import log, run

# Use Xen tapdisk to create block devices from files

blktap2_prefix = "/dev/xen/blktap-2/tapdev"

nbdclient_prefix = "/var/run/blktap-control/nbdclient"

class Tapdisk:
    def __init__(self, minor, pid, f):
        self.minor = minor
        self.pid = pid
        self.f = f
        self.secondary = None # mirror destination
    def destroy(self, dbg):
        self.pause(dbg)
        run(dbg, "tap-ctl destroy -m %d -p %d" % (self.minor, self.pid))
        #run(dbg, "tap-ctl close -m %d -p %d" % (self.minor, self.pid))
        #run(dbg, "tap-ctl detach -m %d -p %d" % (self.minor, self.pid))
        #run(dbg, "tap-ctl free -m %d" % (self.minor))
    def close(self, dbg):
        run(dbg, "tap-ctl close -m %d -p %d" % (self.minor, self.pid))
        self.f = None
    def open(self, dbg, f):
        assert (isinstance(f, image.Vhd) or isinstance(f, image.Raw))
        run(dbg, "tap-ctl open -m %d -p %d -a %s" % (self.minor, self.pid, str(f)))
        self.f = f
    def pause(self, dbg):
        run(dbg, "tap-ctl pause -m %d -p %d" % (self.minor, self.pid))
    def unpause(self, dbg):
        cmd = "tap-ctl unpause -m %d -p %d" % (self.minor, self.pid)
        if self.secondary is not None:
            cmd = cmd + " -2 " + self.secondary
        run(dbg, cmd)
    def block_device(self):
        return blktap2_prefix + str(self.minor)
    def start_mirror(self, dbg, fd):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(nbdclient_prefix + str(self.pid))
        token = "token"
        fdsend.sendfds(sock, token, fds = [ fd ])
        sock.close()
        self.secondary = "nbd:" + token
        self.pause(dbg)
        self.unpause(dbg)
    def stop_mirror(self, dbg):
        self.secondary = None
        self.pause(dbg)
        self.unpause(dbg)

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
                    this = image.Raw(args[len(prefix):])
                    results.append(Tapdisk(minor, pid, this))
                prefix = "vhd:"
                if args.startswith(prefix):
                    this = image.Vhd(args[len(prefix):])
                    results.append(Tapdisk(minor, pid, this))
    return results

def find_by_file(dbg, f):
    assert (isinstance(f, image.Vhd) or isinstance(f, image.Raw))
    for tapdisk in list(dbg):
        if str(f) == str(tapdisk.f):
            return tapdisk
