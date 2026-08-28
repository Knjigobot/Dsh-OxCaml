(* sandbox.ml - Isolated Execution Environment & Virtual Filesystem Implementation *)

type file_entry = {
  path : string;
  content : string;
  modified_at : float;
}

type t = {
  root_dir : string;
  files : (string, file_entry) Hashtbl.t;
}

let create ?(root_dir = "/workspace") () = {
  root_dir;
  files = Hashtbl.create 64;
}

let normalize_path sb path =
  if String.starts_with ~prefix:"/" path then path
  else sb.root_dir ^ "/" ^ path

let write_file sb ~path ~content =
  let p = normalize_path sb path in
  let entry = {
    path = p;
    content;
    modified_at = Unix.gettimeofday ();
  } in
  Hashtbl.replace sb.files p entry;
  Ok ()

let read_file sb ~path =
  let p = normalize_path sb path in
  match Hashtbl.find_opt sb.files p with
  | Some e -> Ok e.content
  | None -> Error (Printf.sprintf "File '%s' does not exist in sandbox" p)

let exists sb ~path =
  let p = normalize_path sb path in
  Hashtbl.mem sb.files p

let remove_file sb ~path =
  let p = normalize_path sb path in
  if Hashtbl.mem sb.files p then begin
    Hashtbl.remove sb.files p;
    Ok ()
  end else
    Error (Printf.sprintf "File '%s' not found" p)

let list_files sb =
  Hashtbl.fold (fun k _ acc -> k :: acc) sb.files []

let eval_command sb cmd =
  let tokens = String.split_on_char ' ' (String.trim cmd) in
  match tokens with
  | ["ls"] ->
    let flist = list_files sb in
    Ok (0, String.concat "\n" flist, "")
  | "cat" :: [path] ->
    (match read_file sb ~path with
     | Ok c -> Ok (0, c, "")
     | Error e -> Ok (1, "", e))
  | "echo" :: rest ->
    let text = String.concat " " rest in
    Ok (0, text, "")
  | "rm" :: [path] ->
    (match remove_file sb ~path with
     | Ok () -> Ok (0, "removed " ^ path, "")
     | Error e -> Ok (1, "", e))
  | "touch" :: [path] ->
    (match write_file sb ~path ~content:"" with
     | Ok () -> Ok (0, "", "")
     | Error e -> Ok (1, "", e))
  | other ->
    Ok (0, Printf.sprintf "mock_exec: %s" (String.concat " " other), "")

let snapshot sb =
  Hashtbl.fold (fun k v acc -> (k, v.content) :: acc) sb.files []

let restore sb snap =
  Hashtbl.clear sb.files;
  List.iter (fun (k, c) ->
    let _ = write_file sb ~path:k ~content:c in ()
  ) snap
