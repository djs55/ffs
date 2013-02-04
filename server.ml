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

let run cmd =
  info "shell %s" cmd;
  let f = Filename.temp_file name name in
  let _ = Sys.command (Printf.sprintf "%s > %s" cmd f) in
  let output = string_of_file f in
  let _ = Sys.command (Printf.sprintf "rm %s" f) in
  output

let endswith suffix x =
  let suffix' = String.length suffix in
  let x' = String.length x in
  x' >= suffix' && (String.sub x (x' - suffix') suffix' = suffix)

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
    let oc = open_out state_path in
    output_string oc txt;
    flush oc;
    close_out oc
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
    include Storage_skeleton.VDI

    let vdi_info_of path =
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
            snapshot_time = "";
            snapshot_of = "";
            read_only = false;
            virtual_size = stats.st_size;
            physical_utilisation = stats.st_size;
            sm_config = [];
            persistent = true;
          } else None
        end
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
            |> List.map VDI.vdi_info_of
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
    let create ctx ~dbg ~sr ~device_config ~physical_size = ()
  end
  module UPDATES = struct include Storage_skeleton.UPDATES end
  module TASK = struct include Storage_skeleton.TASK end
  module Policy = struct include Storage_skeleton.Policy end
  module DATA = struct include Storage_skeleton.DATA end
  let get_by_name = Storage_skeleton.get_by_name
end

module Server = Storage_interface.Server(Implementation)

