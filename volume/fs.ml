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

let readme_ext = "readme"

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
  let all = uri' |> mountpoint |> Sys.readdir |> Array.to_list in
  (* base images have a readme file *)
  let all = List.filter (fun x -> not(List.mem (x ^ "." ^ readme_ext) all)) all in
  (* no readme files *)
  List.filter (fun x -> not(Common.endswith ("." ^ readme_ext) x)) all

let path_of uri' key = Filename.concat (mountpoint uri') key

exception Skip

let volume_of_file uri' filename =
  try
    let open Unix.LargeFile in
    let path = path_of uri' filename in
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

let choose_filename uri' name =
  let name' = String.length name in
  let existing = ls uri' in
  let largest_suffix =
    existing
    |>  (List.filter (Common.startswith name))
    |>  (List.map (fun x -> String.sub x name' (String.length x - name')))
    |>  (List.map (fun x -> try int_of_string x with _ -> 0))
    |>  (List.fold_left max 0) in
  let existing = ls uri' in
  if List.mem name existing then name ^ (string_of_int (largest_suffix + 1)) else name

module Disk_tree = struct

  type t = {
    children: string list;
  } with rpc
  (** A node in a managed tree of disk images *)

  let marker = "Machine readable data follows - DO NOT EDIT\n"
  let marker_regex = Re_str.regexp_string marker

  let filename uri' name = path_of uri' name ^ "." ^ readme_ext

  let read uri' name =
    try
      let txt = Common.string_of_file (filename uri' name) in
      match Re_str.bounded_split_delim marker_regex txt 2 with
      | [ _; x ] -> Some (t_of_rpc (Jsonrpc.of_string x))
      | _ -> None
    with e ->
      Common.debug "No .readme file containing child information for %s" name;
      None   
    
  let write uri' name t =
    let image_filename = path_of uri' name in
    let preamble = [
      "Warning";
      "=======";
      Printf.sprintf "The file %s is a link in a chain of image files; it contains some" image_filename;
      "of the disk blocks needed to reconstruct the virtual disk.";
      "";
      Printf.sprintf "DO NOT delete %s unless you are SURE it is nolonger referenced by" image_filename;
      "any other image files. The system will automatically delete the file when it is";
      "nolonger needed.";
      "";
      "Explanation of the data below";
      "-----------------------------";
      "The machine-readable data below lists the image files which depend on this one.";
      "When all these files are deleted it should be safe to delete this file.";
    ] in
    let txt = String.concat "" (List.map (fun x -> x ^ "\n") preamble) ^ marker ^ (Jsonrpc.to_string (rpc_of_t t)) in
    Common.file_of_string (filename uri' name) txt

  let get_parent format image_filename =
    let open Qemu in
    match format with
    | Vhd -> failwith "unimplemented"
    | Qcow2 ->
      let info = Qemu.info image_filename in
      begin match info.Qemu.backing_file with
      | None -> None
      | Some x -> Some (Filename.basename x)
      end
    | Raw -> None

  let rec rm format uri' name =
    let image_filename = path_of uri' name in
    begin match get_parent format image_filename with
    | Some parent ->
      begin match read uri' parent with
        | None ->
          Common.error "image node %s has no associated metadata -- I can't risk deleting it" parent
        | Some t ->
          let children = List.filter (fun x -> x <> name) t.children in
          if children = [] then begin
            Common.debug "image node %s has no children: deleting" parent;
            rm format uri' parent
          end else begin
            Common.debug "image node %s now has children: [ %s ]" parent (String.concat "; " children);
            write uri' parent { children }
          end
      end
    | None -> ()
    end;
    Common.rm_f image_filename;
    Common.rm_f (image_filename ^ "." ^ readme_ext)

  let rename format uri' src dst =
    let image_filename = path_of uri' src in
    match get_parent format image_filename with
    | Some parent ->
      begin match read uri' parent with
      | None ->
        Common.error "image node %s has no associated metadata -- I can't risk manipulating it" parent;
        failwith "image metadata integrity check failed"
      | Some t ->
        let children = dst :: (List.filter (fun x -> x <> src) t.children) in
        write uri' parent { children }
      end
    | None -> ()
end

let create uri' name kind =
  let dir = mountpoint uri' in
  let size = match kind with
  | `New size -> size
  | `Snapshot parent ->
    let parent' = Qemu.info (path_of uri' parent) in
    parent'.Qemu.virtual_size in
  let name = choose_filename uri' (mangle_name name) in
  Qemu.check_size size;
  (* Note: qemu won't fail if we give an existing filename. Caveat user! *)
  let path = path_of uri' name in
  match kind with
  | `New size ->
    Qemu.create path size;
    name
  | `Snapshot parent ->
    (* Rename the existing parent to 'base' *)
    let base = choose_filename uri' (name ^ "-base") in
    Disk_tree.rename Qemu.Qcow2 dir parent base;
    Unix.rename (path_of uri' parent) (path_of uri' base);
    (* Replace the parent with a leaf *)
    Qemu.snapshot (path_of uri' parent) base (* relative *) Qemu.Qcow2 size;
    (* Create a snapshot leaf *)
    let snapshot = choose_filename uri' (name ^ "-snap") in
    Qemu.snapshot (path_of uri' snapshot) base (* relative *) Qemu.Qcow2 size;
    Disk_tree.(write uri' base { children = [ parent; snapshot ] });
    snapshot

let rm uri' name = Disk_tree.rm Qemu.Qcow2 uri' name
