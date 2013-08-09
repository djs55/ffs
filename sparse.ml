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

open Common

let create vdi_path virtual_size =
  let f = Unix.openfile vdi_path [ Unix.O_CREAT; Unix.O_WRONLY ] 0 in
  finally
    (fun () ->
      let _ : int64 = Unix.LargeFile.lseek f (Int64.sub virtual_size 1L) Unix.SEEK_SET in
      let n = Unix.write f "\000" 0 1 in
      if n <> 1 then begin
        error "Failed to create %s" vdi_path;
        failwith (Printf.sprintf "Failed to create %s" vdi_path)
      end
    ) (fun () -> Unix.close f)

let destroy vdi_path =
  try Unix.unlink vdi_path with _ -> ()

let attach path read_write = {
  Storage_interface.params = Losetup.add path read_write;
  xenstore_data = []
}

let detach = Losetup.remove_by_device

let activate _ _ = ()
let deactivate _ = ()
