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

open Xcp_service

let driver = "libvirt"
let name = "sm-libvirt"
let description = "XCP -> libvirt storage connector"
let vendor = "Citrix"
let copyright = "Citrix Inc"
let minor_version = 1
let major_version = 0
let version = Printf.sprintf "%d.%d" major_version minor_version
let required_api_version = "2.0"
let features = [
  "VDI_CREATE", 0L;
  "VDI_DELETE", 0L;
  "VDI_ATTACH", 0L;
  "VDI_DETACH", 0L;
  "VDI_ACTIVATE", 0L;
  "VDI_DEACTIVATE", 0L;
]
let _path = "path"
let _name = "name"
let _uri  = "uri"
let configuration = [
   _path, "path in the filesystem to store disk images";
   _name, "name of the libvirt storage pool";
   _uri, "URI of the hypervisor to use";
]

let json_suffix = ".json"
let state_path = Printf.sprintf "/var/run/nonpersistent/%s%s" name json_suffix

module D = Debug.Make(struct let name = "ffs" end)
open D

module C = Libvirt.Connect
module P = Libvirt.Pool
module V = Libvirt.Volume

let conn = ref None

let get_connection ?name () = match !conn with
  | None ->
    let c = C.connect ?name () in
    conn := Some c;
    c
  | Some c -> c

type sr = {
  pool: Libvirt.rw P.t;
}

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
  let get id =
    if not(Hashtbl.mem table id)
    then raise (Sr_not_attached id)
    else Hashtbl.find table id
  let put id sr =
    if Hashtbl.mem table id
    then raise (Sr_attached id)
    else Hashtbl.replace table id sr
  let remove id =
    if not(Hashtbl.mem table id)
    then raise (Sr_not_attached id)
    else Hashtbl.remove table id
  let num_attached () = Hashtbl.fold (fun _ _ acc -> acc + 1) table 0
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

    let vdi_path_of sr vdi = "XXX"

    let vdi_info_of_name pool name =
        let v = V.lookup_by_name pool name in
        (* let info = V.get_info v in *)
        let key = V.get_key v in
        Some {
            vdi = key;
            content_id = "";
            name_label = name;
            name_description = "";
            ty = "user";
            metadata_of_pool = "";
            is_a_snapshot = false;
            snapshot_time = iso8601_of_float 0.;
            snapshot_of = "";
            read_only = false;
            virtual_size = 0L; (*info.V.capacity;*)
            physical_utilisation = 0L; (*info.V.allocation;*)
            sm_config = [];
            persistent = true;
        }

    let choose_filename sr vdi_info =
      let existing = Sys.readdir "XXX" |> Array.to_list in
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
      failwith "unimplemented"

    let destroy ctx ~dbg ~sr ~vdi =
      let sr = Attached_srs.get sr in
      failwith "unimplemented"

    let stat ctx ~dbg ~sr ~vdi = assert false
    let attach ctx ~dbg ~dp ~sr ~vdi ~read_write =
      let sr = Attached_srs.get sr in
      let path = vdi_path_of sr vdi in
      {
        params = "XXX";
        xenstore_data = []
      }
    let detach ctx ~dbg ~dp ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let path = vdi_path_of sr vdi in
      ()
    let activate ctx ~dbg ~dp ~sr ~vdi = ()
    let deactivate ctx ~dbg ~dp ~sr ~vdi = ()
  end
  module SR = struct
    open Storage_skeleton.SR
    let list = list
    let scan ctx ~dbg ~sr =
       let sr = Attached_srs.get sr in
       let pool = Libvirt.Pool.const sr.pool in
       let count = Libvirt.Pool.num_of_volumes pool in
       Libvirt.Pool.list_volumes pool count
       |> Array.to_list
       |> List.map (VDI.vdi_info_of_name pool)
       |> List.fold_left (fun acc x -> match x with
             | None -> acc
             | Some x -> x :: acc) []

    let destroy = destroy
    let reset = reset
    let detach ctx ~dbg ~sr =
       Attached_srs.remove sr;
       if Attached_srs.num_attached () = 0
       then match !conn with
       | Some c ->
            C.close c;
            conn := None
       | None -> ()

    let optional device_config key =
      if List.mem_assoc key device_config
      then Some (List.assoc key device_config)
      else None
    let require device_config key =
      if not(List.mem_assoc key device_config) then begin
        error "Required device_config:%s not present" key;
        raise (Missing_configuration_parameter key)
      end else List.assoc key device_config


    let attach ctx ~dbg ~sr ~device_config =
       let name = require device_config _name in
       let uri = optional device_config _uri in
       let c = get_connection ?name:uri () in
       let pool = P.lookup_by_name c name in
       Attached_srs.put sr { pool }

    let create ctx ~dbg ~sr ~device_config ~physical_size =
       let name = require device_config _name in
       let uri = optional device_config _uri in
       let path = require device_config _path in
       let xml = Printf.sprintf "
         <pool type=\"dir\">
           <name>%s</name>
           <target>
             <path>%s</path>
           </target>
         </pool>
       " name path in
       let c = get_connection ?name:uri () in
       let _ = Libvirt.Pool.create_xml c xml in
       ()
  end
  module UPDATES = struct include Storage_skeleton.UPDATES end
  module TASK = struct include Storage_skeleton.TASK end
  module Policy = struct include Storage_skeleton.Policy end
  module DATA = struct include Storage_skeleton.DATA end
  let get_by_name = Storage_skeleton.get_by_name
end

module Server = Storage_interface.Server(Implementation)

