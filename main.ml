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

module D = Debug.Make(struct let name = "ffs" end)
open D

open Server

(* Server configuration. We have built-in (hopefully) sensible defaults,
   together with a configuration file.
*)
let config_file = ref (Printf.sprintf "/etc/%s.conf" name)
let pidfile = ref (Printf.sprintf "/var/run/%s.pid" name)
let daemon = ref false

let config_spec = [
  "socket", Arg.Set_string Storage_interface.default_path, (fun () -> !Storage_interface.default_path), "Directory to create listening sockets";
  "pidfile", Arg.Set_string pidfile, (fun () -> !pidfile), "Location to store the process pid";
  "daemon", Arg.Bool (fun b -> daemon := b), (fun () -> string_of_bool !daemon), "True if we want to daemonize";
  "disable-logging-for", Arg.String
    (fun x ->
      try
        let modules = Re_str.split (Re_str.regexp "[ ]+") x in
        List.iter Debug.disable modules
      with e ->
        error "Processing disabled-logging-for = %s: %s" x (Printexc.to_string e)
    ), (fun () -> String.concat " " (!Debug.disabled_modules)), "A space-separated list of debug modules to suppress logging from";
  "config", Arg.Set_string config_file, (fun () -> !config_file), "Location of configuration file";
] @ Path.config_spec

let arg_spec = List.map (fun (a, b, _, c) -> "-" ^ a, b, c) config_spec

let read_config_file () =
  if Sys.file_exists !config_file then begin
    (* Will raise exception if config is mis-formatted. It's up to the
       caller to inspect and handle the failure.
    *)
    Config_parser.parse_file !config_file config_spec;
    debug "Read global variables successfully from %s" !config_file
  end;
  (* Check the required binaries are all available *)
  List.iter
    (fun (access, name, path, descr) ->
      try
        Unix.access !path [ access ]
      with _ ->
        error "Cannot access %s: please set %s in %s" !path descr !config_file;
        error "For example:";
        error "    # %s" descr;
	error "    %s=/path/to/%s" name name;
        exit 1
    ) Path.essentials

(* Normal HTTP POST and GET *)
let http_handler s () =
  let ic = Unix.in_channel_of_descr s in
  let oc = Unix.out_channel_of_descr s in
  let module Request = Cohttp.Request.Make(Cohttp_posix_io.Buffered_IO) in
  let module Response = Cohttp.Response.Make(Cohttp_posix_io.Buffered_IO) in
  match Request.read ic with
    | None ->
      debug "Failed to read HTTP request"
    | Some req ->
      begin match Request.meth req, Uri.path (Request.uri req) with
      | `GET, "/" ->
        let response_txt = "<html><body>Hello there</body></html>" in
        let content_length = String.length response_txt in
        let headers = Cohttp.Header.of_list [
          "user-agent", "xenopsd";
          "content-length", string_of_int content_length;
        ] in
        let response = Response.make ~version:`HTTP_1_1 ~status:`OK ~headers ~encoding:(Cohttp.Transfer.Fixed content_length) () in
        Response.write (fun t oc -> Response.write_body t oc response_txt) response oc
      | `POST, _ ->
        begin match Request.header req "content-length" with
        | None ->
          debug "Failed to read content-length"
        | Some content_length ->
          let content_length = int_of_string content_length in
          let request_txt = String.make content_length '\000' in
          really_input ic request_txt 0 content_length;
          let rpc_call = Xmlrpc.call_of_string request_txt in
          debug "%s" (Rpc.string_of_call rpc_call);
          let rpc_response = Server.process () rpc_call in
          debug "   %s" (Rpc.string_of_response rpc_response);
          let response_txt = Xmlrpc.string_of_response rpc_response in
          let content_length = String.length response_txt in
          let headers = Cohttp.Header.of_list [
            "user-agent", name;
            "content-length", string_of_int content_length;
          ] in
          let response = Response.make ~version:`HTTP_1_1 ~status:`OK ~headers ~encoding:(Cohttp.Transfer.Fixed content_length) () in
          Response.write (fun t oc -> Response.write_body t oc response_txt) response oc
        end
      | _, _ ->
        let content_length = 0 in
        let headers = Cohttp.Header.of_list [
          "user-agent", name;
          "content-length", string_of_int content_length;
        ] in
        let response = Response.make ~version:`HTTP_1_1 ~status:`Not_found ~headers ~encoding:(Cohttp.Transfer.Fixed content_length) () in
        Response.write (fun t oc -> ()) response oc
      end

let accept_forever sock f =
  let (_: Thread.t) = Thread.create
    (fun () ->
      while true do
        let this_connection, _ = Unix.accept sock in
        let (_: Thread.t) = Thread.create
          (fun () ->
            Config_parser.finally
              (fun () -> f this_connection)
              (fun () -> Unix.close this_connection)
          ) () in
        ()
      done
    ) () in
  ()

let start domain_sock =
  (* JSON/HTTP over domain_sock, no fd passing *)
  accept_forever domain_sock
    (fun s ->
      http_handler s ()
    )

let prepare_unix_domain_socket path =
  try
    (try Unix.mkdir (Filename.dirname path) 0o700 with Unix.Unix_error(Unix.EEXIST, _, _) -> ());
    (try Unix.unlink path with _ -> ());
    let sock = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
    Unix.bind sock (Unix.ADDR_UNIX path);
    Unix.listen sock 5;
    sock
  with e ->
    error "Failed to listen on Unix domain socket %s. Raw error was: %s" path (Printexc.to_string e);
    begin match e with
    | Unix.Unix_error(Unix.EACCES, _, _) ->
      error "Access was denied.";
      error "Possible fixes include:";
      error "1. Run this program as root (recommended)";
      error "2. Make the permissions in the filesystem more permissive (my effective uid is %d)" (Unix.geteuid ());
      error "3. Adjust the sockets-path directive in %s" !config_file;
      exit 1
    | _ -> ()
    end;
    raise e

let daemonize () =
  match Unix.fork () with
  | 0 ->
    if Unix.setsid () == -1 then
      failwith "Unix.setsid failed";

    begin match Unix.fork () with
    | 0 ->
      let nullfd = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
      begin try
        Unix.close Unix.stdin;
        Unix.dup2 nullfd Unix.stdout;
        Unix.dup2 nullfd Unix.stderr;
      with exn -> Unix.close nullfd; raise exn
      end;
      Unix.close nullfd
    | _ -> exit 0
    end
  | _ -> exit 0

(** create a directory, and create parent if doesn't exist *)
let mkdir_rec dir perm =
  let rec p_mkdir dir =
    let p_name = Filename.dirname dir in
    if p_name <> "/" && p_name <> "." 
    then p_mkdir p_name;
    (try Unix.mkdir dir perm with Unix.Unix_error(Unix.EEXIST, _, _) -> ()) in
  p_mkdir dir

let main () =
  debug "%s version %d.%d starting" name major_version minor_version;

  Arg.parse (Arg.align arg_spec)
    (fun _ -> failwith "Invalid argument")
    (Printf.sprintf "Usage: %s [-config filename]" name);

  read_config_file ();
  Config_parser.dump config_spec;

  if !daemon then begin
    debug "About to daemonize";
    Debug.output := Debug.syslog name ();
    daemonize();
  end;

  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;

  (* Accept connections before we have daemonized *)
  let domain_sock = prepare_unix_domain_socket (!Storage_interface.default_path) in

  mkdir_rec (Filename.dirname !pidfile) 0o755;
  (* Unixext.pidfile_write !pidfile; *) (* XXX *)

  start domain_sock

let _ = main ()
