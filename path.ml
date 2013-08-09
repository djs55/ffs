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

open Unix

let essentials = [
  X_OK, "losetup", Losetup.losetup, "path to the losetup binary";
  X_OK, "qemu-img", Qemu.qemu_img, "path to the qemu-img binary";
]

let nonessentials = [
]

let canonicalise x = Filename.(if is_relative x then concat (Unix.getcwd ()) x else x)

let config_spec = List.map (fun (_, a, b, c) -> a, Arg.String (fun x -> b := canonicalise x), (fun () -> !b), c) (essentials @ nonessentials)
