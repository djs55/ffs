#!/usr/bin/env python

from common import call

"""
Manage an open-iscsi initiator
"""


class Address:

    def __init__(self, ip, port):  # NOQA
        self.ip = ip
        self.port = port

    def __init__(self, txt):  # NOQA
        self.ip = txt.split(":")[0]
        self.port = int(txt.split(":")[1].split(",")[0])


class Target:

    def __init__(self, address, iqn):  # NOQA
        self.address = address
        self.iqn = iqn

    def __init__(self, txt):  # NOQA
        bits = txt.split(" ")
        self.address = Address(bits[0])
        self.iqn = bits[1]


class Session:

    def __init__(self, proto, index, ip, port, iqn):  # NOQA
        self.proto = proto
        self.index = index
        self.ip = ip
        self.port = port
        self.iqn = iqn

    def __init__(self, txt):  # NOQA
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
        return map(
            lambda x: Session(x), call(
                dbg, [
                    "iscsiadm", "-m", "session"]).split("\n"))

    def discover(self, dbg, address):
        return map(lambda x: Target(x),
                   call(dbg,
                        ["iscsiadm",
                         "--mode",
                         "discoverydb",
                         "--type",
                         "sendtargets",
                         "--portal",
                         address,
                         "--discover"]).split("\n"))
