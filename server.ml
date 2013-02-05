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

let driver = "ffs"
let name = "ffs"
let description = "Flat File Storage Repository for XCP"
let vendor = "Citrix"
let copyright = "Citrix Inc"
let minor_version = 1
let major_version = 0
let version = Printf.sprintf "%d.%d" major_version minor_version
let required_api_version = "2.0"
let features = [

]
let _path = "path"
let configuration = [
   _path, "path in the filesystem to store images and metadata";
]

let json_suffix = ".json"
let state_path = Printf.sprintf "/var/run/nonpersistent/%s%s" name json_suffix

module D = Debug.Make(struct let name = "ffs" end)
open D

type sr = {
  path: string;
} with rpc
type srs = (string * sr) list with rpc

let finally f g =
  try
    let result = f () in
    g ();
    result
  with e ->
    g ();
    raise e

let string_of_file filename =
  let ic = open_in filename in
  let output = Buffer.create 1024 in
  try
    while true do
      let block = String.make 4096 '\000' in
      let n = input ic block 0 (String.length block) in
      if n = 0 then raise End_of_file;
      Buffer.add_substring output block 0 n
    done;
    "" (* never happens *)
  with End_of_file ->
    close_in ic;
    Buffer.contents output

let file_of_string filename string =
  let oc = open_out filename in
  finally
    (fun () ->
      debug "write >%s %s" filename string;
      output oc string 0 (String.length string)
    ) (fun () -> close_out oc)

let run cmd =
  info "shell %s" cmd;
  let f = Filename.temp_file name name in
  let cmdline = Printf.sprintf "%s > %s 2>&1" cmd f in
  let code = Sys.command cmdline in
  let output = string_of_file f in
  let _ = Sys.command (Printf.sprintf "rm %s" f) in
  if code = 0
  then output
  else failwith (Printf.sprintf "%s: %d: %s" cmdline code output)

let startswith prefix x =
  let prefix' = String.length prefix in
  let x' = String.length x in
  x' >= prefix' && (String.sub x 0 prefix' = prefix)

let remove_prefix prefix x =
  let prefix' = String.length prefix in
  let x' = String.length x in
  String.sub x prefix' (x' - prefix')

let endswith suffix x =
  let suffix' = String.length suffix in
  let x' = String.length x in
  x' >= suffix' && (String.sub x (x' - suffix') suffix' = suffix)

let iso8601_of_float x = 
  let time = Unix.gmtime x in
  Printf.sprintf "%04d%02d%02dT%02d:%02d:%02dZ"
    (time.Unix.tm_year+1900)
    (time.Unix.tm_mon+1)
    time.Unix.tm_mday
    time.Unix.tm_hour
    time.Unix.tm_min
    time.Unix.tm_sec

let ( |> ) a b = b a

open Storage_interface

module Attached_srs = struct
  let table = Hashtbl.create 16
  let save () =
    let srs = Hashtbl.fold (fun id sr acc -> (id, sr) :: acc) table [] in
    let txt = Jsonrpc.to_string (rpc_of_srs srs) in
    let dir = Filename.dirname state_path in
    if not(Sys.file_exists dir)
    then ignore (run (Printf.sprintf "mkdir -p %s" dir));
    file_of_string state_path txt
  let load () =
    if Sys.file_exists state_path then begin
      info "Loading state from: %s" state_path;
      let all = string_of_file state_path in
      let srs = srs_of_rpc (Jsonrpc.of_string all) in
      Hashtbl.clear table;
      List.iter (fun (id, sr) -> Hashtbl.replace table id sr) srs
    end else info "No saved state; starting with an empty configuration"

  (* On service start, load any existing database *)
  let _ = load ()
  let get id =
    if not(Hashtbl.mem table id)
    then raise (Sr_not_attached id)
    else Hashtbl.find table id
  let put id sr =
    if Hashtbl.mem table id
    then raise (Sr_attached id)
    else Hashtbl.replace table id sr;
    save ()
  let remove id =
    if not(Hashtbl.mem table id)
    then raise (Sr_not_attached id)
    else Hashtbl.remove table id
end

module Losetup = struct
  let find file =
    (* /dev/loop0: [0801]:196616 (/tmp/foo/bar) *)
    match Re_str.split_delim (Re_str.regexp_string ":") (run (Printf.sprintf "losetup -j %s" file)) with
    | device :: _ -> Some device
    | _ -> None

  let add file read_write =
      match find file with
      | None ->
        ignore (run (Printf.sprintf "losetup %s -f %s" (if read_write then "" else "-r") file));
        begin match find file with
        | None -> failwith (Printf.sprintf "Failed to add a loop device for %s" file)
        | Some x -> x
        end
      | Some x -> x

  let remove file =
      match find file with
      | None -> ()
      | Some device -> ignore (run (Printf.sprintf "losetup -d %s" device))
end

module Implementation = struct
  type context = unit

  module Query = struct
    let query ctx ~dbg = {
        driver;
        name;
        description;
        vendor;
        copyright;
        version;
        required_api_version;
        features;
        configuration;
    }

    let diagnostics ctx ~dbg = "Not available"
  end
  module DP = struct include Storage_skeleton.DP end
  module VDI = struct
    (* The following are all not implemented: *)
    open Storage_skeleton.VDI
    let clone = clone
    let snapshot = snapshot
    let epoch_begin = epoch_begin
    let epoch_end = epoch_end
    let get_url = get_url
    let set_persistent = set_persistent
    let compose = compose
    let similar_content = similar_content
    let add_to_sm_config = add_to_sm_config
    let remove_from_sm_config = remove_from_sm_config
    let set_content_id = set_content_id
    let get_by_name = get_by_name

    let vdi_path_of sr vdi =
        Filename.concat sr.path vdi

    let md_path_of sr vdi =
        vdi_path_of sr vdi ^ json_suffix

    let vdi_info_of_path path =
        let md_path = path ^ json_suffix in
        if Sys.file_exists md_path then begin
          let txt = string_of_file md_path in
          Some (vdi_info_of_rpc (Jsonrpc.of_string txt))
        end else begin
          let open Unix.LargeFile in
          let stats = stat path in
          if stats.st_kind = Unix.S_REG && not (endswith json_suffix path) then Some {
            vdi = Filename.basename path;
            content_id = "";
            name_label = Filename.basename path;
            name_description = "";
            ty = "user";
            metadata_of_pool = "";
            is_a_snapshot = false;
            snapshot_time = iso8601_of_float 0.;
            snapshot_of = "";
            read_only = false;
            virtual_size = stats.st_size;
            physical_utilisation = stats.st_size;
            sm_config = [];
            persistent = true;
          } else None
        end

    let choose_filename sr vdi_info =
      let existing = Sys.readdir sr.path |> Array.to_list in
      if not(List.mem vdi_info.name_label existing)
      then vdi_info.name_label
      else
        let stem = vdi_info.name_label ^ "." in
        let with_common_prefix = List.filter (startswith stem) existing in
        let suffixes = List.map (remove_prefix stem) with_common_prefix in
        let highest_number = List.fold_left (fun acc suffix ->
          let this = try int_of_string suffix with _ -> 0 in
          max acc this) 0 suffixes in
        stem ^ (string_of_int (highest_number + 1))

    let create ctx ~dbg ~sr ~vdi_info =
      let sr = Attached_srs.get sr in
      let vdi_info = { vdi_info with
        vdi = choose_filename sr vdi_info;
        snapshot_time = iso8601_of_float 0.
      } in
      let vdi_path = vdi_path_of sr vdi_info.vdi in
      let md_path = md_path_of sr vdi_info.vdi in

      ignore(run(Printf.sprintf "dd if=/dev/zero of=%s seek=%Ld count=1 bs=1" vdi_path vdi_info.virtual_size));
      file_of_string md_path (Jsonrpc.to_string (rpc_of_vdi_info vdi_info));
      vdi_info

    let destroy ctx ~dbg ~sr ~vdi =
      let sr = Attached_srs.get sr in
      if not(Sys.file_exists (vdi_path_of sr vdi)) && not(Sys.file_exists (md_path_of sr vdi))
      then raise (Vdi_does_not_exist vdi);
      ignore(run(Printf.sprintf "rm -f %s %s" (vdi_path_of sr vdi) (md_path_of sr vdi)))

    let stat ctx ~dbg ~sr ~vdi = assert false
    let attach ctx ~dbg ~dp ~sr ~vdi ~read_write =
      let sr = Attached_srs.get sr in
      let path = vdi_path_of sr vdi in
      let device = Losetup.add path read_write in {
        params = device;
        xenstore_data = []
      }
    let detach ctx ~dbg ~dp ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let path = vdi_path_of sr vdi in
      Losetup.remove path
    let activate ctx ~dbg ~dp ~sr ~vdi = ()
    let deactivate ctx ~dbg ~dp ~sr ~vdi = ()
  end
  module SR = struct
    open Storage_skeleton.SR
    let list = list
    let scan ctx ~dbg ~sr =
       let sr = Attached_srs.get sr in
       if not(Sys.file_exists sr.path)
       then []
       else
          Sys.readdir sr.path
            |> Array.to_list
            |> List.map (Filename.concat sr.path)
            |> List.map VDI.vdi_info_of_path
            |> List.fold_left (fun acc x -> match x with
               | None -> acc
               | Some x -> x :: acc) []

    let destroy = destroy
    let reset = reset
    let detach ctx ~dbg ~sr =
       Attached_srs.remove sr
    let attach ctx ~dbg ~sr ~device_config =
       if not(List.mem_assoc _path device_config) then begin
           error "Required device_config:path not present";
           raise (Missing_configuration_parameter _path);
       end;
       let path = List.assoc _path device_config in
       Attached_srs.put sr { path }
    let create ctx ~dbg ~sr ~device_config ~physical_size =
       (* attach will validate the device_config parameters *)
       attach ctx ~dbg ~sr ~device_config;
       detach ctx ~dbg ~sr
  end
  module UPDATES = struct include Storage_skeleton.UPDATES end
  module TASK = struct include Storage_skeleton.TASK end
  module Policy = struct include Storage_skeleton.Policy end
  module DATA = struct include Storage_skeleton.DATA end
  let get_by_name = Storage_skeleton.get_by_name
end

module Server = Storage_interface.Server(Implementation)

