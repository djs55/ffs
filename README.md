Flat File Storage (FFS)
-----------------------

This is an experimental XenServer storage service which can be
used to manage virtual disks on an existing filesystem.

FFS supports:

  * vhd-format files via libvhd
  * qcow2-format files via qemu

over the usual operations:

  * create: makes a new virtual disk
  * destroy: destroys a virtual disk
  * clone: makes a copy-on-write clone of a virtual disk
  * snapshot: makes a read-only point-in-time snapshot of a virtual disk
  * resize: resizes the virtual size of a virtual disk (not necessarily the size of the on-disk footprint)
  * scan: lists the available virtual disks

FFS is designed to work with an existing filesystem which may have
been network-mounted. FFS has no explicit support for cross-host locking
so it is important that clients not try to do anything silly like
access the same virtual disk from two different machines. FFS does
no active disk coalescing so it is possible to share the same *disk tree*
across multiple hosts, provided each host writes to a distinct set of
virtual disks.

Installation
------------

The simplest way to try this software is to install the
[xenserver-core](http://www.xenserver.org/blog.html)
packages.

On CentOS 6.4 x86_64:

```
rpm -ihv http://xenbits.xen.org/djs/xenserver-core-latest-snapshot.x86_64.rpm
yum install -y xenserver-core
xenserver-install-wizard
```

and then you can create a build environment by:

```
yum install -y yum-utils
yum-builddep -y ffs
```

Configuration
-------------

An SR may be created via the XenAPI as follows:

```
xe sr-create type=ffs name-label="My new FFS SR" device-config:path=/usr/share/xapi/qcow2 device-config:format=qcow2
```


