#!/usr/bin/env python

import os
import errno
import signal
import pickle
import xapi
import commands
from common import log, run
import image, losetup, dmsetup, tapdisk

def path_to_persist(image):
    return "/tmp/persist" + image.path

class Device:
    def save(self):
        path = path_to_persist(self.image)
        to_create = os.path.dirname(path)
        try:
            os.makedirs(to_create)
        except OSError as exc:
            if exc.errno == errno.EEXIST and os.path.isdir(to_create):
                pass
            else: raise
        with open(path, "w") as f:
            pickle.dump(self, f)

    def __init__(self, image):
        self.image = image
        self.block = None
        self.save()

    def block_device(self):
        dbg = "Device.block_device"
        if self.block is None:
            self.connected = True
            if isinstance(self.image, image.Raw):
                self.loop = losetup.find(dbg, self.image.path)
                if self.loop is None:
                    self.loop = losetup.create(dbg, self.image.path)
                self.dm = dmsetup.find(dbg, self.loop.block_device())
                if self.dm is None:
                    self.dm = dmsetup.create(dbg, self.loop.block_device())
                self.block = self.dm.block_device ()
                return self.block
            elif isinstance(self.image, image.Vhd):
                raise "FIXME vhd"
        else:
            return self.block

    def destroy(self, dbg):
        if self.dm is not None:
            self.dm.destroy(dbg)
            self.dm = None
        if self.loop is not None:
            self.loop.destroy(dbg)
            self.loop = None
        self.block = None

def create(dbg, i):
    assert isinstance(i, image.Path)
    path = path_to_persist(i)
    if os.path.exists(path):
        with open(path) as f:
            return (pickle.load(f))
    else:
        return Device(i)
