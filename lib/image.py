#!/usr/bin/env python

import os
import os.path


class Path:

    """An entity on the filesystem"""

    def __init__(self, path):
        self.path = os.path.realpath(path)


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
