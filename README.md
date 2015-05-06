Flat File Storage (FFS)
-----------------------

This is an experimental XenServer storage service which can be
used to manage virtual disks on an existing filesystem.

FFS supports:

  * raw files, attached to VMs via losetup and blkback

over the usual operations:

  * create: makes a new virtual disk
  * destroy: destroys a virtual disk
  * ls: lists the available virtual disks

FFS is designed to work with an existing filesystem which may have
been network-mounted. FFS has no explicit support for cross-host locking
so it is important that clients not try to do anything silly like
access the same virtual disk from two different machines.

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
xe sr-create type=ffs name-label="My new FFS SR" device-config:path=/usr/share/xapi/images
```


