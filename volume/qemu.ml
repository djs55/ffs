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

type format =
  | Vhd
  | Raw
  | Qcow2

let qemu_img = ref "/usr/bin/qemu-img"

let string_of_format = function
  | Qcow2 -> "qcow2"
  | Raw -> "raw"
  | Vhd -> "vdi"

let kib = 1024L
let mib = Int64.(kib * kib)
let gib = Int64.(kib * mib)

(* See RWMJ's blog: http://rwmj.wordpress.com/2011/10/03/maximum-qcow2-disk-size/ *)
let maximum_size = 9223372036854774784L

let minimum_size = 0L

let check_size proposed_size =
  if proposed_size < minimum_size || proposed_size > maximum_size then begin
    let msg = Printf.sprintf "Cannot create qcow2 with virtual_size = %Ld MiB (must be between %Ld MiB and %Ld MiB)" Int64.(proposed_size / mib) Int64.(minimum_size / mib) Int64.(maximum_size / mib) in
    failwith msg
  end

let create ?options ?(format=Qcow2) path size =
  check_size size;
  let options = match options with
    | None -> []
    | Some x -> [ "-o"; x ] in
  let args = [ "create"; "-f"; string_of_format format ] @ options @ [ path; Int64.to_string size ] in
  let (_: string) = run !qemu_img args in
  ()

let snapshot leaf_path parent_path parent_format virtual_size =
  create ~options:("backing_file=" ^ parent_path ^ ",backing_fmt=" ^ (string_of_format parent_format)) leaf_path virtual_size 

let resize ?(format=Qcow2) path new_virtual_size =
  check_size new_virtual_size;
  let args = [ "resize"; "-f"; string_of_format format; path; Int64.to_string new_virtual_size ] in
  let (_: string) = run !qemu_img args in
  new_virtual_size

let newline_regex = Re_str.regexp_string "\n"
let colon_regex = Re_str.regexp ":[ ]*"
let space_regex = Re_str.regexp_string " "

(* Example qemu-img info output:
# qemu-img info -f qcow2 glacier.qcow2 
image: glacier.qcow2
file format: qcow2
virtual size: 8.0G (8589934592 bytes)
disk size: 1.4M
cluster_size: 65536
backing file: name
*)

(* Result of a qemu-img info *)
type info = {
  format: string;
  virtual_size: int64;
  disk_size: int64;
  cluster_size: int64;
  backing_file: string option;
}

(* keys in the qemu-img info output: *)
let _image = "image"
let _file_format = "file format"
let _virtual_size = "virtual size"
let _disk_size = "disk size"
let _cluster_size = "cluster_size"
let _backing_file = "backing file"

let info ?(format=Qcow2) path =
  let args = [ "info"; "-f"; string_of_format format; path ] in
  let result = run !qemu_img args in
  let lines = Re_str.split_delim newline_regex result in
  let table = List.concat (List.map (fun line ->
    match Re_str.bounded_split_delim colon_regex line 2 with
    | [k; v] -> [k, v]
    | _ -> []
  ) lines) in
  let find key =
    if not(List.mem_assoc key table)
    then failwith (Printf.sprintf "failed to find '%s' in qemu-img info output" key)
    else List.assoc key table in
  let find_opt key =
    if not(List.mem_assoc key table)
    then None
    else Some (List.assoc key table) in
  let parse_size size =
    let fragments = Re_str.split_delim space_regex size in
    match List.fold_left (fun best_guess x ->
      if x <> "" then begin
        if x.[0] = '('
        then Some (Int64.of_string (String.sub x 1 (String.length x - 1)))
        else
          if best_guess = None then begin
            let suffix = x.[String.length x - 1] in
            let prefix = String.sub x 0 (String.length x - 1) in
            if suffix = 'T'
            then Some (Int64.of_float (float_of_string prefix *. 1024. *. 1024. *. 1024. *. 1024.))
            else if suffix = 'G'
            then Some (Int64.of_float (float_of_string prefix *. 1024. *. 1024. *. 1024.))
            else if suffix = 'M'
            then Some (Int64.of_float (float_of_string prefix *. 1024. *. 1024.))
            else if suffix = 'K'
            then Some (Int64.of_float (float_of_string prefix *. 1024.))
            else None
          end else best_guess
       end else best_guess 
     ) None fragments with
     | None -> failwith (Printf.sprintf "Failed to parse_size '%s'" size)
     | Some x -> x in
 {
      format = find _file_format;
      virtual_size = parse_size (find _virtual_size);
      disk_size = parse_size (find _disk_size);
      cluster_size = Int64.of_string (find _cluster_size);
      backing_file = find_opt _backing_file;
  }

let destroy vdi_path =
  try Unix.unlink vdi_path with _ -> ()

let detach device = ()

let activate _ _ = ()
let deactivate _ = ()
