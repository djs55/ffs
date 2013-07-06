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

let mount_cmd = ref "/bin/mount"
let umount_cmd = ref "/bin/umount"

let mount remote local =
  let (_: string) = Common.run !mount_cmd [ "-t"; "nfs"; remote; local ] in
  ()

let umount local =
  let (_: string) = Common.run !umount_cmd [ local ] in
  ()

