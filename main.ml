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
  "use-switch", Arg.Set Xcp_client.use_switch, (fun () -> string_of_bool !Xcp_client.use_switch), "true if we want to use the message switch";
  "socket-path", Arg.Set_string socket_path, (fun () -> !socket_path), "Path of listening socket";
  "queue-name", Arg.Set_string Storage_interface.queue_name, (fun () -> !Storage_interface.queue_name), "Name of queue to listen on";
]

let main () =
  debug "%s version %d.%d starting" name major_version minor_version;
  (* The default queue name: *)
  Storage_interface.queue_name := "org.xen.xcp.storage.libvirt";

  configure ~options ~resources ();
  let server = Xcp_service.make ~path:!socket_path
    ~queue_name:!Storage_interface.queue_name
    ~rpc_fn:(fun s -> Server.process () s) () in

  Xcp_service.maybe_daemonize ();

  Xcp_service.serve_forever server

let _ = main ()
