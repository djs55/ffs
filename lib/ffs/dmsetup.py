#!/usr/bin/env python

import xapi
import fcntl
import log
import os
import array
import struct
from common import call

# Use device mapper to suspend and resume block devices


def blkgetsize64(path):
    req = 0x80081272
    buf = ' ' * 8
    with open(path) as dev:
        buf = fcntl.ioctl(dev.fileno(), req, buf)
    return struct.unpack('L', buf)[0]


def blkszget(path):
    req = 0x1268
    buf = array.array('c', [chr(0)] * 4)
    with open(path) as dev:
        fcntl.ioctl(dev.fileno(), req, buf)
    return struct.unpack('I', buf)[0]


def name_of_device(device):
    """For a given device path, compute a suitable device mapper name.
       We wish it to be obvious which device mapper node corresponds to
       which original device."""
    dm = ""
    for char in device:
        char = char.lower()
        if ord(char) >= ord('a') and ord(char) <= ord('z'):
            dm = dm + char
        elif ord(char) >= ord('0') and ord(char) <= ord('9'):
            dm = dm + char
        elif char in ['-', '+', '=']:
            dm = dm + char
        else:
            dm = dm + "_"
    return dm


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
        self.name = name_of_device(base_device)
        t = table(base_device)
        existing = call(dbg, ["dmsetup", "table", self.name]).strip()
        if existing != t:
            message = ("Device mapper device %s has table %s, expected %s" %
                       (self.name, existing, t))
            log.error("%s: %s" % (dbg, message))
            raise xapi.InternalError(message)

    def suspend(self, dbg):
        call(dbg, ["dmsetup", "suspend", self.name])

    def resume(self, dbg):
        call(dbg, ["dmsetup", "resume", self.name])

    def reload(self, dbg, base_device):
        t = table(base_device)
        call(dbg, ["dmsetup", "reload", self.name, "--table", t])

    def destroy(self, dbg):
        call(dbg, ["dmsetup", "remove", self.name])

    def block_device(self):
        return "/dev/mapper/%s" % self.name


def find(dbg, base_device):
    try:
        return DeviceMapper(dbg, base_device)
    except:
        return None


def create(dbg, base_device):
    try:
        return DeviceMapper(dbg, base_device)
    except:
        call(dbg, ["dmsetup", "create", name_of_device(
            base_device), "--table", table(base_device)])
        return DeviceMapper(dbg, base_device)
