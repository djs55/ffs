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

open Int64

let kib = 1024L
let mib = mul kib kib
let gib = mul kib mib
let mib_minus_1 = sub mib 1L
let max_size = mul gib 2040L

let roundup v block =
  mul block (div (sub (add v block) 1L) block)

let create path size =
  let size = roundup size two_mib in
  if size < mib or size > max_size
  then failwith (Printf.sprintf "VDI size must be between 1 MiB and %d MiB" max_size);
