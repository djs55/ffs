(*
 * Copyright (C) Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)

type statvfs_t = {
        f_bsize : int64;
        f_frsize : int64;
        f_blocks : int64;
        f_bfree : int64;
        f_bavail : int64;
        f_files : int64;
        f_ffree : int64;
        f_favail : int64;
        f_fsid : int64;
        f_flag : int64;
        f_namemax : int64;
}

external statvfs : string -> statvfs_t = "stub_statvfs"

