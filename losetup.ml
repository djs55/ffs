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

let losetup = ref "/sbin/losetup"

let find file =
  (* /dev/loop0: [0801]:196616 (/tmp/foo/bar) *)
  match Re_str.split_delim (Re_str.regexp_string ":") (run !losetup ["-j"; file]) with
  | device :: _ -> Some device
  | _ -> None

let add file read_write =
    match find file with
    | None ->
      ignore (run !losetup ((if read_write then [] else ["-r"]) @ ["-f"; file]));
      begin match find file with
      | None -> failwith (Printf.sprintf "Failed to add a loop device for %s" file)
      | Some x -> x
      end
    | Some x -> x

let remove_by_device device =
    ignore(run !losetup [ "-d"; device ])

let remove_by_file file =
    match find file with
    | None -> ()
    | Some device -> remove_by_device device
