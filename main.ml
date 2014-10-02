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

let resources = [
  { Xcp_service.name = "losetup";
    description = "used to set up loopback block devices";
    essential = true;
    path = Losetup.losetup;
    perms = [ Unix.X_OK ];
  }; {
    Xcp_service.name = "mount";
    description = "used to mount remote filesystems";
    essential = true;
    path = Mount.mount_cmd;
    perms = [ Unix.X_OK ];
  }; {
    Xcp_service.name = "umount";
    description = "used to unmount remote filesystems";
    essential = true;
    path = Mount.umount_cmd;
    perms = [ Unix.X_OK ];
  }
]

let socket_path = ref !Storage_interface.default_path

let comma = Re_str.regexp_string ","
let csv = Re_str.split_delim comma

let queues : string list ref = ref [
  "org.xen.xcp.storage.ffs";
]

let options = [
  "use-switch", Arg.Set Xcp_client.use_switch, (fun () -> string_of_bool !Xcp_client.use_switch), "true if we want to use the message switch";
  "socket-path", Arg.Set_string socket_path, (fun () -> !socket_path), "Path of listening socket";
  "queue-name", Arg.String (fun x -> queues := csv x), (fun () -> String.concat "," !queues), "Comma-separated list of queue names to listen on";
  "default-format", Arg.String Server.set_default_format, Server.get_default_format, "Default format for disk files";
  "sr-mount-path", Arg.Set_string Server.mount_path, (fun () -> !Server.mount_path), "Default mountpoint for mounting remote filesystems";
]

let doc = String.concat "\n" [
  "A simple filesystem-based storage implementation for xapi";
  "";
  "Ffs manages disk files from a user-supplied directory. The user is expected to mount and unmount the directory themselves (e.g. NFS via /etc/fstab). Ffs will create disk image files in vhd, qcow2 or raw format. Ffs will use readable names for the disk files (avoiding UUIDs). Note that ffs performs no file locking, so use shared filesystems at your own risk.";
]

let main () =
  debug "%s version %s starting" Server.name Version.version;

  (match Xcp_service.configure2
    ~name:(Filename.basename Sys.argv.(0))
    ~version:Version.version
    ~doc ~options ~resources () with
  | `Ok () -> ()
  | `Error m ->
    error "%s" m;
    exit 1);

  let servers = List.map (fun queue_name ->
    Xcp_service.make ~path:!socket_path ~queue_name
      ~rpc_fn:(fun s -> Server.Server.process () s) ()
  ) !queues in

  Xcp_service.maybe_daemonize ();

  let threads = List.map (Thread.create Xcp_service.serve_forever) servers in
  List.iter Thread.join threads

let _ = main ()
