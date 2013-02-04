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

let state_path = Printf.sprintf "/var/run/nonpersistent/%s.json" name

module D = Debug.Make(struct let name = "ffs" end)
open D

type sr = {
  path: string;
} with rpc
type srs = (string * sr) list with rpc

let read_lines ic =
  let results = ref [] in
  try
    while true do
      results := input_line ic :: !results
    done;
    [] (* never happens *)
  with End_of_file ->
    List.rev !results

let run cmd =
  info "shell %s" cmd;
  let f = Filename.temp_file name name in
  let _ = Sys.command (Printf.sprintf "%s > %s" cmd f) in
  let ic = open_in f in
  let output = read_lines ic in
  close_in ic;
  let _ = Sys.command (Printf.sprintf "rm %s" f) in
  output

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
      let ic = open_in state_path in
      let all = input_line ic in
      close_in ic;
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
  module VDI = struct include Storage_skeleton.VDI end
  module SR = struct
    open Storage_skeleton.SR
    let list = list
    let scan = scan
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

