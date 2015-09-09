#!/usr/bin/env python

import os
import signal

# from python-fdsend
# import fdsend

import xapi
import image
from common import call

# Use Xen tapdisk to create block devices from files

blktap2_prefix = "/dev/xen/blktap-2/tapdev"

nbdclient_prefix = "/var/run/blktap-control/nbdclient"
nbdserver_prefix = "/var/run/blktap-control/nbdserver"


class Tapdisk:

    def __init__(self, minor, pid, f):
        self.minor = minor
        self.pid = pid
        self.f = f
        self.secondary = None  # mirror destination

    def destroy(self, dbg):
        self.pause(dbg)
        call(dbg,
             ["tap-ctl",
              "destroy",
              "-m",
              str(self.minor),
              "-p",
              str(self.pid)])

    def close(self, dbg):
        call(dbg,
             ["tap-ctl",
              "close",
              "-m",
              str(self.minor),
              "-p",
              str(self.pid)])
        self.f = None

    def open(self, dbg, f):
        assert (isinstance(f, image.Vhd) or isinstance(f, image.Raw))
        call(dbg, ["tap-ctl", "open", "-m", str(self.minor),
                   "-p", str(self.pid), "-a", str(f)])
        self.f = f

    def pause(self, dbg):
        call(dbg,
             ["tap-ctl",
              "pause",
              "-m",
              str(self.minor),
              "-p",
              str(self.pid)])

    def unpause(self, dbg):
        cmd = ["tap-ctl", "unpause", "-m",
               str(self.minor), "-p", str(self.pid)]
        if self.secondary is not None:
            cmd = cmd + ["-2 ", self.secondary]
        call(dbg, cmd)

    def block_device(self):
        return blktap2_prefix + str(self.minor)

    """
    ToDo: fdsend needs to be imported
    def start_mirror(self, dbg, fd):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(nbdclient_prefix + str(self.pid))
        token = "token"
        fdsend.sendfds(sock, token, fds=[fd])
        sock.close()
        self.secondary = "nbd:" + token
        self.pause(dbg)
        self.unpause(dbg)
    """

    def stop_mirror(self, dbg):
        self.secondary = None
        self.pause(dbg)
        self.unpause(dbg)

    """
    ToDo: fdsend needs to be imported
    def receive_nbd(self, dbg, fd):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect("%s%d.%d" % (nbdserver_prefix, self.pid, self.minor))
        token = "token"
        fdsend.sendfds(sock, token, fds=[fd])
        sock.close()
    """


def create(dbg):
    output = call(dbg, ["tap-ctl", "spawn"]).strip()
    pid = int(output)
    output = call(dbg, ["tap-ctl", "allocate"]).strip()
    prefix = blktap2_prefix
    minor = None
    if output.startswith(prefix):
        minor = int(output[len(prefix):])
    if minor is None:
        os.kill(pid, signal.SIGQUIT)
        raise xapi.InternalError("tap-ctl allocate returned unexpected " +
                                 "output: %s" % (output))
    call(dbg, ["tap-ctl", "attach", "-m", str(minor), "-p", str(pid)])
    return Tapdisk(minor, pid, None)


def list(dbg):
    results = []
    for line in call(dbg, ["tap-ctl", "list"]).split("\n"):
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
            before, args = line.split("args=")
            prefix = "aio:"
            if args.startswith(prefix):
                this = image.Raw(os.path.realpath(args[len(prefix):]))
                results.append(Tapdisk(minor, pid, this))
            prefix = "vhd:"
            if args.startswith(prefix):
                this = image.Vhd(os.path.realpath(args[len(prefix):]))
                results.append(Tapdisk(minor, pid, this))
    return results


def find_by_file(dbg, f):
    assert (isinstance(f, image.Path))
    path = os.path.realpath(f.path)
    for tapdisk in list(dbg):
        if tapdisk.f is not None and tapdisk.f.path == path:
            return tapdisk
