#!/usr/bin/env python

import xapi
import commands
import fcntl, os, array, struct, sys

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

# Use device mapper to suspend and resume block devices

# VG_XenStorage--770cdfa8--ccbf--d209--46ed--72e8e65f926a-MGT: 0 8192 linear 8:3 118912

# dmsetup create test --table "0 8192 linear 8:3 118912"

def blkgetsize64(path):
    req = 0x80081272
    buf = ' ' * 8
    fmt = 'L'
    with open(path) as dev:
        buf = fcntl.ioctl(dev.fileno(), req, buf)
    return struct.unpack('L', buf)[0]

def blkszget(path):
    req=0x1268
    buf = array.array('c', [chr(0)] * 4)
    with open(path) as dev:
        fcntl.ioctl(dev.fileno(), req, buf)
    return struct.unpack('I',buf)[0]

    logical_sector_size = ioctl_read_uint32(fd, BLKSSZGET)

def free_name(dbg):
    return "test"

def table(base_device):
    logical_sector_size = blkszget(base_device)
    bytes = blkgetsize64(base_device)
    total_sectors = bytes / logical_sector_size
    stats = os.stat(base_device) 
    major = os.major(stats.st_rdev) 
    minor = os.minor(stats.st_rdev)
    return "0 %d linear %d:%d 0" % (total_sectors, major, minor)

class DeviceMapper:
    def __init__(self, dbg, base_device):
        self.name = free_name(dbg)
        t = table(base_device)
        run(dbg, "dmsetup create %s --table \"%s\"" % (self.name, t))

    def suspend(self, dbg):
        run(dbg, "dmsetup suspend %s" % self.name)
    def resume(self, dbg):
        run(dbg, "dmsetup resume %s" % self.name)
    def reload(self, dbg, base_device):
        t = table(base_device)
        run(dbg, "dmsetup reload %s --table \"%s\"" % (self.name, t))
    def destroy(self, dbg):
        run(dbg, "dmsetup remove %s" % self.name)

def create(dbg, base_device):
    return DeviceMapper(dbg, base_device)

