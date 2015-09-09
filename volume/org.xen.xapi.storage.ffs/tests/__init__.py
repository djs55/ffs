import os
import sys

# Fake automatically generated RPC interfaces


class TestPlugin:

    class TestPlugin_skeleton:
        pass

    Plugin_skeleton = TestPlugin_skeleton


class TestSrnotattachedexception(Exception):
    pass


class TestVolume:

    class TestSR_skeleton:
        pass
    SR_skeleton = TestSR_skeleton

    class Testvolume_skeleton:
        pass
    Volume_skeleton = Testvolume_skeleton

    Sr_not_attached = TestSrnotattachedexception


class TestDatapath:

    class TestDatapath_skeleton:
        pass
    Datapath_skeleton = TestDatapath_skeleton


class TestXapi:
    plugin = TestPlugin()
    volume = TestVolume()
    datapath = TestDatapath()

sys.modules['xapi'] = TestXapi
sys.modules['xapi.volume'] = TestVolume
sys.modules['xapi.plugin'] = TestPlugin
sys.modules['xapi.datapath'] = TestDatapath

# fix include paths
path_of_this_script = os.path.dirname(os.path.abspath(__file__))
path_of_lib_folder = os.path.join(path_of_this_script, '..', '..', 'lib')
sys.path.append(path_of_lib_folder)
