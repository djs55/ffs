#!/usr/bin/env python

import os
import errno
import signal
import pickle
import xapi
import commands
from common import log, run
import image

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
        self.save()

def create(dbg, i):
    assert isinstance(i, image.Path)
    path = path_to_persist(i)
    if os.path.exists(path):
        with open(path) as f:
            return (pickle.load(f))
    else:
        return Device(i)
