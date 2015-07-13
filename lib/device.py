#!/usr/bin/env python

import os
import errno
import pickle
from common import call
import image
import losetup
import dmsetup
import tapdisk

persist_root = "/tmp/persist"


def path_to_persist(image):
    return persist_root + image.path


def clear():
    call("clear", ["rm", "-rf", persist_root])


class Device:

    def save(self):
        path = path_to_persist(self.image)
        to_create = os.path.dirname(path)
        try:
            os.makedirs(to_create)
        except OSError as exc:
            if exc.errno == errno.EEXIST and os.path.isdir(to_create):
                pass
            else:
                raise
        with open(path, "w") as f:
            pickle.dump(self, f)

    def __init__(self, image):
        self.image = image
        self.loop = None
        self.block = None
        self.tapdisk = None
        self.dm = None
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
                self.block = self.dm.block_device()
                self.save()
                return self.block
            elif isinstance(self.image, image.Vhd):
                self.tapdisk = tapdisk.create(dbg)
                self.tapdisk.open(dbg, self.image)
                self.block = self.tapdisk.block_device()
                self.save()
                return self.block
        else:
            return self.block

    def add_tapdisk(self, dbg):
        if self.tapdisk is None:
            self.tapdisk = tapdisk.create("")
            self.tapdisk.open(dbg, self.image)
            if self.dm is not None:
                self.dm.suspend(dbg)
                self.dm.reload(dbg, self.tapdisk.block_device())
                self.dm.resume(dbg)
                if self.loop is not None:
                    self.loop.destroy(dbg)
                    self.loop = None
            self.block = self.dm.block_device()
            self.save()

    def remove_tapdisk(self, dbg):
        if isinstance(self.image, image.Vhd):
            return  # not possible to remove a tapdisk
        if self.tapdisk is not None:
            if self.dm is not None:
                self.dm.suspend(dbg)
                if self.loop is None:
                    self.loop = losetup.create(dbg, self.image.path)
                self.dm.reload(dbg, self.loop.block_device())
                self.dm.resume(dbg)
                self.tapdisk.destroy(dbg)
                self.tapdisk = None
                self.save()

    def destroy(self, dbg):
        if self.dm is not None:
            self.dm.destroy(dbg)
            self.dm = None
        if self.loop is not None:
            self.loop.destroy(dbg)
            self.loop = None
        if self.tapdisk is not None:
            self.tapdisk.destroy(dbg)
            self.tapdisk = None
        self.block = None
        self.save()


def create(dbg, i):
    assert isinstance(i, image.Path)
    path = path_to_persist(i)
    if os.path.exists(path):
        with open(path) as f:
            return (pickle.load(f))
    else:
        return Device(i)
