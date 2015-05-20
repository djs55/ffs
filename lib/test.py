# Run these tests with 'nosetests':
#   install the 'python-nose' package (Fedora/CentOS or Ubuntu)
#   run 'nosetests' in the root of the repository

import unittest

class Tests(unittest.TestCase):
    # unittest.TestCase has more methods than Pylint permits
    # pylint: disable=R0904

    def setUp(self):
        pass

    def test_raw(self):
        self.assertEqual("foo", "foo")
