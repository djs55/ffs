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

module D = Debug.Make(struct let name = "ffs" end)
include D

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
      debug "write >%s" filename;
      output oc string 0 (String.length string)
    ) (fun () -> close_out oc)

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


(** create a directory, and create parent if doesn't exist *)
let mkdir_rec dir perm =
  let mkdir_safe dir perm =
    try Unix.mkdir dir perm with Unix.Unix_error (Unix.EEXIST, _, _) -> () in
  let rec p_mkdir dir =
    let p_name = Filename.dirname dir in
    if p_name <> "/" && p_name <> "." 
    then p_mkdir p_name;
    mkdir_safe dir perm in
  p_mkdir dir

let rm_f x =
  try
    Unix.unlink x;
    debug "rm %s" x
   with _ ->
    debug "%s already deleted" x;
    ()

let ( |> ) a b = b a

let retry_every n f =
  let finished = ref false in
  while (not !finished) do
    try
      let () = f () in
      finished := true;
    with e ->
      debug "Caught %s: sleeping %f. before trying again" (Printexc.to_string e) n;
      Thread.delay n
  done

type format =
  | Vhd
  | Raw
  | Qcow2
with rpc

let string_of_format = function
  | Vhd -> "vhd"
  | Raw -> "raw"
  | Qcow2 -> "qcow2"

let format_of_string x = match String.lowercase x with
  | "vhd" -> Some Vhd
  | "raw" -> Some Raw
  | "qcow2" -> Some Qcow2
  | y ->
    None

type sr = {
  sr: string;
  path: string;
  is_mounted: bool;
  format: format;
} with rpc

let iso_ext = "iso"
let vhd_ext = "vhd"
let qcow2_ext = "qcow2"
let json_ext = "json"
let readme_ext = "readme"

let vdi_path_of sr vdi = Filename.concat sr.path vdi

let run cmd args =
  debug "exec %s %s" cmd (String.concat " " args);
  let null = Unix.openfile "/dev/null" [ Unix.O_RDWR ] 0 in
  let to_close = ref [ null ] in
  let close fd =
    if List.mem fd !to_close then begin
      to_close := List.filter (fun x -> x <> fd) !to_close;
      Unix.close fd
    end in
  let close_all () = List.iter close !to_close in
  try
    let b = Buffer.create 128 in
    let tmp = String.make 4096 '\000' in
    let readable, writable = Unix.pipe () in
    to_close := readable :: writable :: !to_close;
    let pid = Unix.create_process cmd (Array.of_list (cmd :: args)) null writable null in
    close writable;
    let finished = ref false in
    while not !finished do
      let n = Unix.read readable tmp 0 (String.length tmp) in
      Buffer.add_substring b tmp 0 n;
      finished := n = 0
    done;
    close_all ();
    let _, status = Unix.waitpid [] pid in
    match status with
    | Unix.WEXITED 0 -> Buffer.contents b
    | Unix.WEXITED n ->
      failwith (Printf.sprintf "%s %s: %d (%s)" cmd (String.concat " " args) n (Buffer.contents b))
    | _ ->
      failwith (Printf.sprintf "%s %s failed" cmd (String.concat " " args))
  with e ->
    close_all ();
    raise e
