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

type t = {
  children: string list;
} with rpc
(** A node in a managed tree of disk images *)

let marker = "Machine readable data follows - DO NOT EDIT\n"
let marker_regex = Re_str.regexp_string marker

let filename sr name = Filename.concat sr.path name ^ "." ^ readme_ext
  let read sr name =
    let txt = string_of_file (filename sr name) in
    match Re_str.bounded_split_delim marker_regex txt 2 with
    | [ _; x ] -> Some (t_of_rpc (Jsonrpc.of_string x))
    | _ -> None
       
let write sr name t =
  let image_filename = vdi_path_of sr name in
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
  file_of_string (filename sr name) txt

let get_parent format image_filename =
  match format with
  | Vhd -> Vhdformat.get_parent image_filename
  | Qcow2 ->
    let info = Qemu.info image_filename in
    begin match info.Qemu.backing_file with
    | None -> None
    | Some x -> Some (Filename.basename x)
    end
  | Raw -> None

let rec rm format sr name =
  let image_filename = vdi_path_of sr name in
  begin match get_parent format image_filename with
  | Some parent ->
    begin match read sr parent with
      | None ->
        error "image node %s has no associated metadata -- I can't risk deleting it" parent
      | Some t ->
        let children = List.filter (fun x -> x <> name) t.children in
        if children = [] then begin
          info "image node %s has no children: deleting" parent;
          rm format sr parent
        end else begin
          info "image node %s now has children: [ %s ]" parent (String.concat "; " children);
          write sr parent { children }
        end
    end
  | None -> ()
  end;
  rm_f image_filename;
  rm_f (image_filename ^ "." ^ readme_ext)

let rename format sr src dst =
  let image_filename = vdi_path_of sr src in
  match get_parent format image_filename with
  | Some parent ->
    begin match read sr parent with
    | None ->
      error "image node %s has no associated metadata -- I can't risk manipulating it" parent;
      failwith "image metadata integrity check failed"
    | Some t ->
      let children = dst :: (List.filter (fun x -> x <> src) t.children) in
      write sr parent { children }
    end
  | None -> ()

