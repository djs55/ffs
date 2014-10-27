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

let illegal_names = [ ""; "."; ".." ]

let mangle_name x : string =
  if List.mem x illegal_names (* hopeless *)
  then "unknown-volume"
  else x

let create uri' name kind =
  let dir = mountpoint uri' in
  let size = match kind with
  | `New size -> size
  | `Snapshot parent ->
    let parent' = Qemu.info (Filename.concat dir parent) in
    parent'.Qemu.disk_size in
  let name = mangle_name name in
  let name' = String.length name in
  Qemu.check_size size;
  (* Note: qemu won't fail if we give an existing filename. Caveat user! *)
  let existing = ls uri' in
  let largest_suffix =
    existing
    |>  (List.filter (Common.startswith name))
    |>  (List.map (fun x -> String.sub x name' (String.length x - name')))
    |>  (List.map (fun x -> try int_of_string x with _ -> 0))
    |>  (List.fold_left max 0) in
  let existing = ls uri' in
  let name = if List.mem name existing then name ^ (string_of_int (largest_suffix + 1)) else name in
  let path = Filename.concat dir name in
  match kind with
  | `New size ->
    Qemu.create path size;
    name
  | `Snapshot parent ->
    Qemu.snapshot path parent (* relative *) Qemu.Qcow2 size;
    name
