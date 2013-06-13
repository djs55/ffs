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

let losetup = ref "/sbin/losetup"

let run cmd args =
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
    let pid = Unix.create_process cmd (Array.of_list args) null writable null in
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

let find file =
  (* /dev/loop0: [0801]:196616 (/tmp/foo/bar) *)
  match Re_str.split_delim (Re_str.regexp_string ":") (run !losetup ["-j"; file]) with
  | device :: _ -> Some device
  | _ -> None

let add file read_write =
    match find file with
    | None ->
      ignore (run !losetup ((if read_write then [] else ["-r"]) @ ["-f"; file]));
      begin match find file with
      | None -> failwith (Printf.sprintf "Failed to add a loop device for %s" file)
      | Some x -> x
      end
    | Some x -> x

let remove file =
    match find file with
    | None -> ()
    | Some device -> ignore (run !losetup ["-d"; device])

