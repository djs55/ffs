#!/usr/bin/env python

import os
import signal
import socket

import xapi
import commands
from common import log, run

import unittest
"""
Manage an open-iscsi initiator
"""

class Address:
    def __init__(self, ip, port):
        self.ip = ip
        self.port = port
    def __init__(self, txt):
        self.ip = txt.split(":")[0]
        self.port = int(txt.split(":")[1].split(",")[0])

class Target:
    def __init__(self, address, iqn):
        self.address = address
        self.iqn = iqn 
    def __init__(self, txt):
        bits = txt.split(" ")
        self.address = Address(bits[0])
        self.iqn = bits[1] 

class Session:
    def __init__(self, proto, index, ip, port, iqn):
        self.proto = proto
        self.index = index
        self.ip = ip
        self.port = port
        self.iqn = iqn
    def __init__(self, txt):
        # txt is the output of 'iscsiadm -m session'
        bits = txt.split(" ")
        self.proto = bits[0].strip(":")
        self.index = int(bits[1].strip("[").strip("]"))
        self.address = Address(bits[2])
        self.iqn = bits[3]

class Initiator:
    def __init__(self):
        pass

    def get_sessions(self, dbg):
        return map(lambda x:Session(x), run(dbg, "iscsiadm -m session").split("\n"))

    def discover(self, dbg, address):
        return map(lambda x:Target(x), run(dbg, "iscsiadm --mode discoverydb --type sendtargets --portal %s --discover" % address))
