(* context.ml - Spatial Coeffects & Revertible Disposal Stack Implementation *)

open Types

type 'a key = ..

type any_key = Key : 'a key -> any_key

type t = {
  id : int;
  name : string;
  parent : t option;
  bindings : (any_key, Obj.t) Hashtbl.t;
  dynamic_store : (string, Obj.t) Hashtbl.t;
  mutable effect_stack : (rollback_token * string) list;
}

let next_context_id = ref 1
let next_token_id = ref 1

let create_root name =
  let id = !next_context_id in
  incr next_context_id;
  {
    id;
    name;
    parent = None;
    bindings = Hashtbl.create 32;
    dynamic_store = Hashtbl.create 32;
    effect_stack = [];
  }

let isolate ?(name = "child_scope") parent =
  let id = !next_context_id in
  incr next_context_id;
  {
    id;
    name;
    parent = Some parent;
    bindings = Hashtbl.create 16;
    dynamic_store = Hashtbl.create 16;
    effect_stack = [];
  }

let name ctx = ctx.name
let parent ctx = ctx.parent

let provide ctx k v =
  Hashtbl.replace ctx.bindings (Key k) (Obj.repr v)

let rec inject : type a. t -> a key -> a option =
  fun ctx k ->
    match Hashtbl.find_opt ctx.bindings (Key k) with
    | Some v -> Some (Obj.obj v)
    | None ->
      (match ctx.parent with
       | Some p -> inject p k
       | None -> None)

let set_dynamic ctx k v =
  Hashtbl.replace ctx.dynamic_store k v

let rec get_dynamic ctx k =
  match Hashtbl.find_opt ctx.dynamic_store k with
  | Some v -> Some v
  | None ->
    (match ctx.parent with
     | Some p -> get_dynamic p k
     | None -> None)

let register_effect ctx ~tick ~label revert_fn =
  let token_id = !next_token_id in
  incr next_token_id;
  let token = {
    token_id;
    causal_tick = tick;
    revert_action = revert_fn;
  } in
  ctx.effect_stack <- (token, label) :: ctx.effect_stack;
  token

let rollback_all ctx =
  let rolled_back_labels = ref [] in
  let rec unwind stack =
    match stack with
    | [] -> Ok (List.length !rolled_back_labels, List.rev !rolled_back_labels)
    | (token, label) :: rest ->
      (match token.revert_action () with
       | Ok () ->
         rolled_back_labels := label :: !rolled_back_labels;
         unwind rest
       | Error err ->
         Error (Printf.sprintf "Rollback failed at effect '%s' (token #%d): %s" label token.token_id err))
  in
  let stack = ctx.effect_stack in
  ctx.effect_stack <- [];
  unwind stack

let effect_count ctx = List.length ctx.effect_stack
