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

let mount uri' =
  let uri = Uri.of_string uri' in
  match Uri.scheme uri with
  | Some "file" ->
    (* Check the directory exists *)
    let path = Uri.path uri in
    if not(Sys.is_directory path)
    then raise (Storage.V.SR_does_not_exist uri')
  | Some x ->
    raise (Storage.V.Unimplemented x)
  | None ->
    raise (Failure (Printf.sprintf "Failed to parse URI: %s" uri'))

let umount uri' = ()

let mountpoint uri' =
  let uri = Uri.of_string uri' in
  (* We only support file: URLs so *)
  Uri.path uri

let ls uri' =
  uri' |> mountpoint |> Sys.readdir |> Array.to_list

exception Skip

let volume_of_file uri' filename =
  let mountpoint = mountpoint uri' in
  try
    let open Unix.LargeFile in
    let path = Filename.concat mountpoint filename in
    let stats = stat path in Some {
      Storage.V.Types.key = filename;
      name = filename;
      description = "";
      read_write = true;
      uri = [ (match stats.st_kind with
              | Unix.S_REG -> "file"
              | Unix.S_BLK -> "block"
              | _ -> raise Skip) ^ "://" ^ path ];
      virtual_size = stats.st_size;
    }
  with _ -> None
