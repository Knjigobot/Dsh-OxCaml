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

let tokenize_command input =
  let len = String.length input in
  let buf = Buffer.create 32 in
  let tokens = ref [] in
  let state = ref `Normal in
  let i = ref 0 in
  let flush_token () =
    if Buffer.length buf > 0 then begin
      tokens := Buffer.contents buf :: !tokens;
      Buffer.clear buf
    end
  in
  let err = ref None in
  while !i < len && !err = None do
    let c = input.[!i] in
    match !state with
    | `Normal ->
      if c = ' ' || c = '\t' || c = '\n' || c = '\r' then begin
        flush_token ();
        incr i
      end else if c = '\'' then begin
        state := `Single_quote;
        incr i
      end else if c = '"' then begin
        state := `Double_quote;
        incr i
      end else if c = '\\' then begin
        incr i;
        if !i < len then begin
          Buffer.add_char buf input.[!i];
          incr i
        end else
          err := Some "Trailing backslash escape in command"
      end else begin
        Buffer.add_char buf c;
        incr i
      end
    | `Single_quote ->
      if c = '\'' then begin
        state := `Normal;
        incr i
      end else begin
        Buffer.add_char buf c;
        incr i
      end
    | `Double_quote ->
      if c = '"' then begin
        state := `Normal;
        incr i
      end else if c = '\\' then begin
        incr i;
        if !i < len then begin
          let next_c = input.[!i] in
          if next_c = '"' || next_c = '\\' || next_c = '$' || next_c = '`' then
            Buffer.add_char buf next_c
          else begin
            Buffer.add_char buf '\\';
            Buffer.add_char buf next_c
          end;
          incr i
        end else
          err := Some "Trailing backslash escape inside double quotes"
      end else begin
        Buffer.add_char buf c;
        incr i
      end
  done;
  match !err with
  | Some e -> Error e
  | None ->
    match !state with
    | `Single_quote -> Error "Unclosed single quote in command"
    | `Double_quote -> Error "Unclosed double quote in command"
    | `Normal ->
      flush_token ();
      Ok (List.rev !tokens)

let eval_command sb cmd =
  match tokenize_command (String.trim cmd) with
  | Error err -> Ok (1, "", "Lexer error: " ^ err)
  | Ok [] -> Ok (0, "", "")
  | Ok ("ls" :: _) ->
    let flist = list_files sb in
    Ok (0, String.concat "\n" flist, "")
  | Ok ("cat" :: [path]) ->
    (match read_file sb ~path with
     | Ok c -> Ok (0, c, "")
     | Error e -> Ok (1, "", e))
  | Ok ("echo" :: rest) ->
    let text = String.concat " " rest in
    Ok (0, text, "")
  | Ok ("rm" :: "-f" :: [path]) | Ok ("rm" :: [path]) ->
    (match remove_file sb ~path with
     | Ok () -> Ok (0, "removed " ^ path, "")
     | Error e -> Ok (1, "", e))
  | Ok ("touch" :: [path]) ->
    (match write_file sb ~path ~content:"" with
     | Ok () -> Ok (0, "", "")
     | Error e -> Ok (1, "", e))
  | Ok ("mkdir" :: _rest) ->
    Ok (0, "directory created", "")
  | Ok other ->
    Ok (0, Printf.sprintf "mock_exec: %s" (String.concat " " other), "")

let snapshot sb =
  Hashtbl.fold (fun k v acc -> (k, v.content) :: acc) sb.files []

let restore sb snap =
  Hashtbl.clear sb.files;
  List.iter (fun (k, c) ->
    let _ = write_file sb ~path:k ~content:c in ()
  ) snap
