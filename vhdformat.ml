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

open Storage_interface
open Common
open Int64

let kib = 1024L
let mib = mul kib kib
let gib = mul kib mib
let mib_minus_1 = sub mib 1L
let two_mib = mul mib 2L
let max_size = mul gib 2040L

let roundup v block =
  mul block (div (sub (add v block) 1L) block)

let create path size =
  let size = roundup size two_mib in
  if size < mib or size > max_size then begin
    error "Cannot create vhd with virtual_size = %Ld MiB (must be between 1 MiB and %Ld MiB)" (div size mib) (div max_size mib);
    raise (Backend_error("VDI_SIZE", [ to_string size; to_string mib; to_string (div max_size mib) ]))
  end;
  Vhd.create path size (Vhd.Ty_dynamic) max_size []

let my_context = ref (Tapctl.create ())
let ctx () = !my_context

let t_detach t = Tapctl.detach (ctx ()) t; Tapctl.free (ctx ()) (Tapctl.get_minor t)
let t_pause t =  Tapctl.pause (ctx ()) t
let t_unpause t = Tapctl.unpause (ctx ()) t
let get_paused t = Tapctl.is_paused (ctx ()) t
let get_activated t = Tapctl.is_active (ctx ()) t

let attach _ _ =
  let minor = Tapctl.allocate (ctx ()) in
  let tid = Tapctl.spawn (ctx ()) in
  let dev = Tapctl.attach (ctx ()) tid minor in
  let dest = Tapctl.devnode (ctx ()) (Tapctl.get_minor dev) in
  dest

let activate dev file ty =
  let dev, _, _ = Tapctl.of_device (ctx ()) dev in
  if not (get_activated dev) then begin
    Tapctl._open (ctx ()) dev file ty
  end else begin
    t_pause dev;
    Tapctl.unpause (ctx ()) dev file ty
  end

let deactivate dev =
  let dev, _, _ = Tapctl.of_device (ctx ()) dev in
  Tapctl.close (ctx ()) dev

let detach dev =
  let dev, _, _ = Tapctl.of_device (ctx ()) dev in
  t_detach dev

let snapshot leaf_path parent_path parent_format virtual_size =
  Vhd.snapshot leaf_path virtual_size parent_path max_size (if parent_format = Raw then [Vhd.Flag_creat_parent_raw] else [])

let get_parent path =
  let vhd = Vhd._open path [Vhd.Open_rdonly] in
  finally
    (fun () -> try Some (Filename.basename (Vhd.get_parent vhd)) with _ -> None)
    (fun () -> Vhd.close vhd)
