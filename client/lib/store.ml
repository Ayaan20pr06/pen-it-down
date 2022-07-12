open Lwt.Syntax

module KV =
  Irmin_git.Generic_KV
    (Irmin_indexeddb.Content_store)
    (Irmin_indexeddb.Branch_store)

module Str = KV.Make (Irmin.Contents.String)
module Client = Irmin_client_jsoo.Make (Str)
module Sync = Irmin.Sync.Make (Client)

let get_path key = Str.Schema.Path.v key

let get_value t k = Str.get t k

let list t =
  let* store_list = Str.list t [] in
  Lwt.return @@ List.map fst store_list

let info message () =
  Str.Info.v
    (Unix.gettimeofday () |> Int64.of_float)
    ~author:"penit-client" ~message

let temporary_save t k v =
  let+ response = Str.set ~info:(info "Saving note") t k v in
  match response with Ok () -> "Saved..." | Error _ -> "Error saving..."

let temporary_delete t k =
  let+ response = Str.remove ~info:(info "Deleting note") t k in
  match response with Ok () -> "Deleted..." | Error _ -> "Error deleting..."

let get_store () =
  let config = Irmin_indexeddb.config "penit" in
  let* store_repo = Str.Repo.v config in
  let* store = Str.main store_repo in
  Lwt.return store

(* let push_store () =
  let uri = Uri.of_string "ws://localhost:9090/ws" in
  let* client = Client.connect uri in
  let* main = Client.main client in
  (* let* t = get_store () in
  let* _ = Sync.push_exn t (Irmin.Sync.remote_store (module Client) main) in *)
  let* _ = Sync.push_exn main (Irmin.Sync.remote_store (module Client) main) in
  Lwt.return "push" *)

let pull_store () =
  let uri = Uri.of_string "ws://localhost:9090/ws" in
  let* client = Client.connect uri in
  let* main = Client.main client in
  let* res = Client.ping client in
  match res with
  | Ok () -> (
    let* status =
        Sync.pull_exn main (Irmin.Sync.remote_store (module Client) main) `Set
      in
      match status with
      | `Empty -> Lwt.return "Synced returned empty"
      | `Head _ -> Lwt.return "Synced")
  | Error _ -> Lwt.return "ERROR"
