# Run these tests with 'nosetests':
#   install the 'python-nose' package (Fedora/CentOS or Ubuntu)
#   run 'nosetests' in the root of the repository

import iscsi
import image
import device
import unittest
import os
import socket
import struct
import errno

raw_path = "/tmp/test-raw-disk"


class Tests(unittest.TestCase):
    # unittest.TestCase has more methods than Pylint permits
    # pylint: disable=R0904

    def setUp(self):
        try:
            os.unlink(raw_path)
        except OSError as exc:
            if exc.errno == errno.ENOENT:
                pass
            else:
                raise
        with open(raw_path, "w") as f:
            f.seek(1024 * 1024 - 1)
            f.write("\000")
        device.clear()

    def test_raw(self):
        d = device.create("", image.Raw(raw_path))
        d.destroy("")

    def test_raw_block(self):
        d = device.create("", image.Raw(raw_path))
        block = d.block_device()
        assert block is not None
        d.destroy("")

    def test_raw_block_tapdisk(self):
        d = device.create("", image.Raw(raw_path))
        block = d.block_device()
        assert block is not None
        d.add_tapdisk("")
        d.destroy("")

    def test_mirror(self):
        d = device.create("", image.Raw(raw_path))
        block = d.block_device()
        assert block is not None
        d.add_tapdisk("")
        a, b = socket.socketpair()
        d.tapdisk.start_mirror("", a)
        b.sendall('NBDMAGIC\x00\x00\x42\x02\x81\x86\x12\x53' +
                  struct.pack('>Q', 1024 * 1024) + '\0' * 128)
        d.destroy("")

    def test_nbd(self):
        d = device.create("", image.Raw(raw_path))
        block = d.block_device()
        assert block is not None
        d.add_tapdisk("")
        a, b = socket.socketpair()
        d.tapdisk.receive_nbd("", a)
        results = b.recv(256)
        self.assertEqual("NBDMAGIC", results[0:8])
        d.destroy("")


class SessionTests(unittest.TestCase):
    # unittest.TestCase has more methods than Pylint permits
    # pylint: disable=R0904

    def test_parse(self):
        x = iscsi.Session(
            "tcp: [9] 10.0.0.1:3260,1 " +
            "iqn.2004-04.com.qnap:ts-859uplus:iscsi.foo01.000000 " +
            "(non-flash)")
        assert x.proto == "tcp"
        assert x.index == 9
        assert x.address.ip == "10.0.0.1"
        assert x.address.port == 3260
        assert x.iqn == "iqn.2004-04.com.qnap:ts-859uplus:iscsi.foo01.000000"


class DiscoverTests(unittest.TestCase):
    # unittest.TestCase has more methods than Pylint permits
    # pylint: disable=R0904

    def test_parse(self):
        x = iscsi.Target(
            "10.0.0.1:3260,1 " +
            "iqn.2004-04.com.qnap:ts-859uplus:iscsi.foo01.000000")
        assert x.address.ip == "10.0.0.1"
        assert x.address.port == 3260
        assert x.iqn == "iqn.2004-04.com.qnap:ts-859uplus:iscsi.foo01.000000"
