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
open Common

let driver = "ffs"
let name = "ffs"
let description = "Flat File Storage Repository for XCP"
let vendor = "Citrix"
let copyright = "Citrix Inc"
let required_api_version = "2.0"
let features = [
  "VDI_CREATE", 0L;
  "VDI_DELETE", 0L;
  "VDI_ATTACH", 0L;
  "VDI_DETACH", 0L;
  "VDI_ACTIVATE", 0L;
  "VDI_DEACTIVATE", 0L;
  "VDI_SNAPSHOT", 0L;
  "VDI_CLONE", 0L;
]
let _path = "path"
let _format = "format"
let configuration = [
   _path, "path in the filesystem to store images and metadata";
   _format, "default format for disks (either 'vhd' or 'raw')";
]
let _type = "type" (* in sm-config *)

let iso_ext = "iso"
let vhd_ext = "vhd"
let json_ext = "json"
let readme_ext = "readme"
let state_path = Printf.sprintf "/var/run/nonpersistent/%s.%s" name json_ext
let device_ext = "device"

let dot_regexp = Re_str.regexp_string "."
let extension x = List.hd (List.tl (Re_str.split_delim dot_regexp x))

type sr = {
  sr: string;
  path: string;
  format: format;
} with rpc
type srs = (string * sr) list with rpc

open Storage_interface

let format_of_string x = match String.lowercase x with
  | "vhd" -> Some Vhd
  | "raw" -> Some Raw
  | y ->
    warn "Unknown disk format requested %s (possible values are 'vhd' and 'raw')" y;
    None

let string_of_format = function
  | Vhd -> "vhd"
  | Raw -> "raw"

let default_format = ref Vhd

let format_of_kvpairs key default x =
  match (if List.mem_assoc key x
    then format_of_string (List.assoc key x)
    else None) with
  | Some x -> x
  | None -> default

let set_default_format x =
  begin match (format_of_string x) with
    | Some x ->
      default_format := x;
    | None ->
      ()
  end;
  info "Default disk format will be: %s" (string_of_format !default_format)

let get_default_format () = string_of_format !default_format

module Attached_srs = struct
  let table = Hashtbl.create 16
  let save () =
    let srs = Hashtbl.fold (fun id sr acc -> (id, sr) :: acc) table [] in
    let txt = Jsonrpc.to_string (rpc_of_srs srs) in
    let dir = Filename.dirname state_path in
    if not(Sys.file_exists dir)
    then mkdir_rec dir 0o0755;
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
    (* We won't fail if the SR already attached. FIXME What if the user attempts
       to attach us twice with different configuration? *)
    Hashtbl.replace table id sr;
    save ()
  let remove id =
    Hashtbl.remove table id
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
        version = Version.version;
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

    let device_path_of sr vdi = Printf.sprintf "/var/run/nonpersistent/%s/%s/%s.%s" name sr.sr vdi device_ext

    let md_path_of sr vdi =
        vdi_path_of sr vdi ^ "." ^ json_ext

    let vdi_info_of_path path =
        let md_path = path ^ "." ^ json_ext in
        if Sys.file_exists md_path then begin
          let txt = string_of_file md_path in
          Some (vdi_info_of_rpc (Jsonrpc.of_string txt))
        end else begin
          let open Unix.LargeFile in
          let stats = stat path in
          let ext = extension path in
          (* We usually can't store additonal data in read/only directories
             full of .iso images. We assume these files are Raw.
             Openstack wants to create files with extension .vhd and have
             these detected as vhds. *)
          let ext_format = [
            iso_ext, Raw;
            vhd_ext, Vhd;
          ] in

          if stats.st_kind = Unix.S_REG && not(List.mem ext [ json_ext; readme_ext ]) then Some {
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
            sm_config =
              if List.mem_assoc ext ext_format 
              then [ _type, string_of_format (List.assoc ext ext_format) ]
              else [];
            persistent = true;
          } else None
        end

   let vdi_format_of sr vdi =
     match vdi_info_of_path (vdi_path_of sr vdi) with
     | None ->
       error "VDI %s/%s has no associated vdi_info - I don't know how to operate on it." sr.sr vdi;
       failwith (Printf.sprintf "VDI %s/%s has no vdi_info" sr.sr vdi)
     | Some vdi_info ->
       begin
         if not(List.mem_assoc _type vdi_info.sm_config) then begin
           error "VDI %s/%s has no sm_config:type - I don't know how to operate on it." sr.sr vdi;
           failwith (Printf.sprintf "VDI %s/%s has no sm-config:type" sr.sr vdi)
         end;
         let t = List.assoc _type vdi_info.sm_config in
         match format_of_string t with
         | Some x -> x
         | None ->
           error "VDI %s/%s has an unrecognised sm_config:type=%s - I don't know how to operate on it." sr.sr vdi t;
           failwith (Printf.sprintf "VDI %s/%s has unrecognised sm-config:type=%s" sr.sr vdi t)
       end

    let choose_filename sr vdi_info =
      let existing = Sys.readdir sr.path |> Array.to_list in
      let name_label =
        (* empty filenames are not valid *)
        if vdi_info.name_label = ""
        then "unknown"
        else
          (* only some characters are valid in filenames *)
          let name_label = String.copy vdi_info.name_label in
          for i = 0 to String.length name_label - 1 do
            name_label.[i] <- match name_label.[i] with
              | 'a' .. 'z'
              | 'A' .. 'Z'
              | '0' .. '9'
              | '-' | '_' | '+' -> name_label.[i]
              | _ -> '_'
          done;
          name_label in
      if not(List.mem name_label existing)
      then name_label
      else
        let stem = name_label ^ "." in
        let with_common_prefix = List.filter (startswith stem) existing in
        let suffixes = List.map (remove_prefix stem) with_common_prefix in
        let highest_number = List.fold_left (fun acc suffix ->
          let this = try int_of_string suffix with _ -> 0 in
          max acc this) 0 suffixes in
        stem ^ (string_of_int (highest_number + 1))

    let create ctx ~dbg ~sr ~vdi_info =
      let sr = Attached_srs.get sr in
      let format = format_of_kvpairs _type sr.format vdi_info.sm_config in
      let sm_config = (_type, string_of_format format) :: (List.filter (fun (k, _) -> k <> _type) vdi_info.sm_config) in
      let vdi_info = { vdi_info with
        vdi = choose_filename sr vdi_info;
        snapshot_time = iso8601_of_float 0.;
        sm_config;
      } in
      let vdi_path = vdi_path_of sr vdi_info.vdi in
      let md_path = md_path_of sr vdi_info.vdi in

      begin match format with
      | Vhd -> Vhdformat.create vdi_path vdi_info.virtual_size
      | Raw -> Sparse.create vdi_path vdi_info.virtual_size
      end;
      debug "VDI.create %s -> %s (%Ld)" vdi_info.name_label vdi_path vdi_info.virtual_size;  
      file_of_string md_path (Jsonrpc.to_string (rpc_of_vdi_info vdi_info));
      vdi_info

    module Vhd_tree_node = struct
      type t = {
        children: string list;
      } with rpc

      let marker = "Machine readable data follows - DO NOT EDIT\n"
      let marker_regex = Re_str.regexp_string marker

      let filename sr name = Filename.concat sr.path name ^ "." ^ readme_ext
      let read sr name =
        let txt = string_of_file (filename sr name) in
        match Re_str.bounded_split_delim marker_regex txt 2 with
        | [ _; x ] -> Some (t_of_rpc (Jsonrpc.of_string x))
        | _ -> None
       
      let write sr name t =
        let vhd_filename = vdi_path_of sr name in
        let preamble = [
          "Warning";
          "=======";
          Printf.sprintf "The file %s is a link in a chain of vhd files; it contains some" vhd_filename;
          "of the disk blocks needed to reconstruct the virtual disk.";
          "";
          Printf.sprintf "DO NOT delete %s unless you are SURE it is nolonger referenced by" vhd_filename;
          "any other vhd files. The system will automatically delete the file when it is";
          "nolonger needed.";
          "";
          "Explanation of the data below";
          "-----------------------------";
          "The machine-readable data below lists the vhd files which depend on this one.";
          "When all these files are deleted it should be safe to delete this file.";
        ] in
        let txt = String.concat "" (List.map (fun x -> x ^ "\n") preamble) ^ marker ^ (Jsonrpc.to_string (rpc_of_t t)) in
        file_of_string (filename sr name) txt

      let rec rm sr name =
          let vhd_filename = vdi_path_of sr name in
          begin match Vhdformat.get_parent vhd_filename with
          | Some parent ->
            begin match read sr parent with
            | None ->
              error "vhd node %s has no associated metadata -- I can't risk deleting it" parent
            | Some t ->
              let children = List.filter (fun x -> x <> name) t.children in
              if children = [] then begin
                info "vhd node %s has no children: deleting" parent;
                rm sr parent
              end else begin
                info "vhd node %s now has children: [ %s ]" parent (String.concat "; " children);
                write sr parent { children }
              end
            end
          | None -> ()
          end;
          rm_f vhd_filename;
          rm_f (vhd_filename ^ "." ^ readme_ext)

      let rename sr src dst =
        let vhd_filename = vdi_path_of sr src in
        begin match Vhdformat.get_parent vhd_filename with
        | Some parent ->
          begin match read sr parent with
          | None ->
            error "vhd node %s has no associated metadata -- I can't risk manipulating it" parent;
            failwith "vhd metadata integrity check failed"
          | Some t ->
            let children = dst :: (List.filter (fun x -> x <> src) t.children) in
            write sr parent { children }
          end
        | None -> ()
        end
    end

    let destroy ctx ~dbg ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let vdi_path = vdi_path_of sr vdi in
      if not(Sys.file_exists vdi_path) && not(Sys.file_exists (md_path_of sr vdi))
      then raise (Vdi_does_not_exist vdi);

      debug "VDI.destroy %s" vdi;
      begin match vdi_format_of sr vdi with
      | Vhd -> Vhd_tree_node.rm sr vdi
      | Raw -> Sparse.destroy vdi_path
      end;

      rm_f (md_path_of sr vdi)

    let clone ctx ~dbg ~sr ~vdi_info =
      let sr = Attached_srs.get sr in
      let vdi = vdi_info.vdi in
      let vdi_path = vdi_path_of sr vdi in
      let md_path = md_path_of sr vdi in
      if not(Sys.file_exists vdi_path) && not(Sys.file_exists md_path)
      then raise (Vdi_does_not_exist vdi);
      info "VDI.clone %s" vdi;
      let format = vdi_format_of sr vdi in
      let base = choose_filename sr vdi_info in
      (* TODO: stop renaming because it causes problems on NFS *)
      info "rename %s -> %s" vdi_path (vdi_path_of sr base);
      Vhd_tree_node.rename sr vdi base;
      Unix.rename vdi_path (vdi_path_of sr base);
      Vhdformat.snapshot vdi_path (vdi_path_of sr base) format vdi_info.virtual_size;
      let snapshot = choose_filename sr vdi_info in
      Vhdformat.snapshot (vdi_path_of sr snapshot) (vdi_path_of sr base) format vdi_info.virtual_size;
      Vhd_tree_node.(write sr base { children = [ vdi; snapshot ] });
      let vdi_info = { vdi_info with vdi = snapshot } in
      file_of_string (md_path_of sr snapshot) (Jsonrpc.to_string (rpc_of_vdi_info vdi_info));
      vdi_info

    let snapshot = clone

    let stat ctx ~dbg ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let md_path = md_path_of sr vdi in
      vdi_info_of_rpc (Jsonrpc.of_string (string_of_file md_path))

    let attach ctx ~dbg ~dp ~sr ~vdi ~read_write =
      let sr = Attached_srs.get sr in
      let vdi_path = vdi_path_of sr vdi in
      let device = match vdi_format_of sr vdi with
      | Vhd -> Vhdformat.attach vdi_path read_write
      | Raw -> Sparse.attach vdi_path read_write
      in
      let symlink = device_path_of sr vdi in
      mkdir_rec (Filename.dirname symlink) 0o700;
      Unix.symlink device symlink;
      {
        params = device;
        xenstore_data = []
      }
    let detach ctx ~dbg ~dp ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let symlink = device_path_of sr vdi in
      let device = Unix.readlink symlink in
      (* We can get transient failures from background tasks on the system
         inspecting the block device. We must not allow detach to fail, so
         we should keep retrying until the transient failures stop happening. *)
      retry_every 0.1 (fun () ->
        match vdi_format_of sr vdi with
        | Vhd -> Vhdformat.detach device
        | Raw -> Sparse.detach device
      );
      rm_f symlink
    let activate ctx ~dbg ~dp ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let symlink = device_path_of sr vdi in
      let device = Unix.readlink symlink in
      let path = vdi_path_of sr vdi in
      begin match vdi_format_of sr vdi with
      | Vhd -> Vhdformat.activate device path Tapctl.Vhd
      | Raw -> Sparse.activate device path
      end
    let deactivate ctx ~dbg ~dp ~sr ~vdi =
      let sr = Attached_srs.get sr in
      let symlink = device_path_of sr vdi in
      let device = Unix.readlink symlink in
      begin match vdi_format_of sr vdi with
      | Vhd -> Vhdformat.deactivate device
      | Raw -> Sparse.deactivate device
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
       let format = format_of_kvpairs _format !default_format device_config in
       Attached_srs.put sr { sr; path; format }
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

