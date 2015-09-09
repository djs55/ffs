import mock
import os
import sys
import unittest
import util

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
import volume


class test_volume(unittest.TestCase):

    def check_volume_stat_result(self, stat_result):
        self.assertIsInstance(stat_result["key"], str)
        try:
            self.assertIsInstance(stat_result["uuid"], unicode)
        except:
            self.assertIsInstance(stat_result["uuid"], str)
        try:
            self.assertIsInstance(stat_result["name"], unicode)
        except:
            self.assertIsInstance(stat_result["name"], str)
        try:
            self.assertIsInstance(stat_result["description"], unicode)
        except:
            self.assertIsInstance(stat_result["description"], str)
        self.assertIsInstance(stat_result["read_write"], bool)
        self.assertIsInstance(stat_result["virtual_size"], int)
        self.assertIsInstance(stat_result["physical_utilisation"], int)
        self.assertIsInstance(stat_result["uri"], list)
        self.assertIsInstance(stat_result["keys"], dict)
        self.assertEqual(len(stat_result), 9)

    @mock.patch("ffs.poolhelper.suspend_datapath_in_pool")
    @mock.patch("ffs.poolhelper.resume_datapath_in_pool")
    def test_clone_returns_valid_dict(self, resume_datapath_in_pool,
                                      suspend_datapath_in_pool):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            clone_result = volume.Implementation().clone(
                dbg, testffspath.get_uri(), testvolume)

        self.check_volume_stat_result(clone_result)

    def test_create_returns_valid_dict(self):
        dbg = mock.Mock()
        name = "testname"
        description = "testdescription"
        size = 1337
        with util.TestFFSPath() as testffspath:

            create_result = volume.Implementation().create(
                dbg, testffspath.get_uri(), name, description, size)

        self.check_volume_stat_result(create_result)

    def test_destroy_returns_none(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            destroy_result = volume.Implementation().destroy(
                dbg, testffspath.get_uri(), testvolume)

            self.assertIsNone(destroy_result)

    def test_resize_returns_none(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            resize_result = volume.Implementation().resize(
                dbg, testffspath.get_uri(), testvolume, 1338)

        self.assertIsNone(resize_result)

    def test_set_returns_none(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            set_result = volume.Implementation().set(
                dbg, testffspath.get_uri(), testvolume, "testkey", "testvalue")

            self.assertIsNone(set_result)

    def test_set_description_returns_none(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            set_description_result = volume.Implementation().set_description(
                dbg, testffspath.get_uri(), testvolume, "testdescription")

            self.assertIsNone(set_description_result)

    def test_set_name_returns_none(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            set_name_result = volume.Implementation().set_name(
                dbg, testffspath.get_uri(), testvolume, "testname")

            self.assertIsNone(set_name_result)

    @mock.patch("ffs.poolhelper.suspend_datapath_in_pool")
    @mock.patch("ffs.poolhelper.resume_datapath_in_pool")
    def test_snapshot_returns_valid_dict(self, resume_datapath_in_pool,
                                         suspend_datapath_in_pool):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            snapshot_result = volume.Implementation().snapshot(
                dbg, testffspath.get_uri(), testvolume)

        self.check_volume_stat_result(snapshot_result)

    def test_stat_returns_valid_dict(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            stat_result = volume.Implementation().stat(
                dbg, testffspath.get_uri(), testvolume)

        self.check_volume_stat_result(stat_result)

    def test_unset_returns_none(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            testvolume = testffspath.create_test_volume()

            unset_result = volume.Implementation().unset(
                dbg, testffspath.get_uri(), testvolume, "testkey1")

            self.assertIsNone(unset_result)
