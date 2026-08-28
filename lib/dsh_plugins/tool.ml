(* tool.ml - Typed Tool Registry & Reversible Execution Hooks Implementation *)

open Dsh_core.Types

type param_type =
  | String_t
  | Int_t
  | Float_t
  | Bool_t
  | List_t of param_type

type param_spec = {
  name : string;
  ptype : param_type;
  description : string;
  required : bool;
}

type tool_output = {
  stdout_data : string;
  stderr_data : string;
  exit_code : int;
  rollback_hook : (unit -> (unit, string) result) option;
}

type tool_def = {
  name : string;
  description : string;
  parameters : param_spec list;
  handler : (string * string) list -> Dsh_core.Context.t -> (tool_output, string) result;
}

type registry = {
  table : (string, tool_def) Hashtbl.t;
}

let create_registry () = {
  table = Hashtbl.create 32;
}

let register reg def =
  Hashtbl.replace reg.table def.name def

let lookup reg name =
  Hashtbl.find_opt reg.table name

let validate_args (def : tool_def) (args : (string * string) list) =
  let missing = List.filter (fun p ->
    p.required && not (List.mem_assoc p.name args)
  ) def.parameters in
  match missing with
  | [] -> Ok ()
  | hd :: _ -> Error (Printf.sprintf "Missing required parameter '%s' for tool '%s'" hd.name def.name)

let execute reg ~name ~args ~context ~tick =
  match lookup reg name with
  | None -> Error (Printf.sprintf "Tool '%s' not found in registry" name)
  | Some def ->
    (match validate_args def args with
     | Error e -> Error e
     | Ok () ->
       (match def.handler args context with
        | Ok out ->
          (match out.rollback_hook with
           | Some hook ->
             let _ = Dsh_core.Context.register_effect context ~tick ~label:(Printf.sprintf "tool_exec_%s" name) hook in
             Ok out
           | None -> Ok out)
        | Error err -> Error err))

let list_tools reg =
  Hashtbl.fold (fun _ v acc -> v :: acc) reg.table []
