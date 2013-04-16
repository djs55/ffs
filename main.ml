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
open D

open Server

let losetup = ref "/sbin/losetup"

let resources = [
  { Xcp_service.name = "losetup";
    description = "used to set up loopback block devices";
    essential = true;
    path = losetup;
    perms = [ Unix.X_OK ];
  }
]

let socket_path = ref !Storage_interface.default_path

let options = [
  "socket-path", Arg.Set_string socket_path, (fun () -> !socket_path), "Path of listening socket";
]

let main () =
  debug "%s version %d.%d starting" name major_version minor_version;

  configure ~options ~resources ();
  let socket = listen !socket_path in
  if !Xcp_service.daemon then daemonize ();

  accept_forever socket
    (fun s ->
      http_handler Xmlrpc.call_of_string Xmlrpc.string_of_response Server.process s ()
    );

  wait_forever ()

let _ = main ()
