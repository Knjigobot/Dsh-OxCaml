(** [Dsh_plugins.Tool] - Typed Tool Registry & Reversible Execution Hooks *)

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

type registry

val create_registry : unit -> registry

(** Register a tool definition *)
val register : registry -> tool_def -> unit

(** Lookup tool by name *)
val lookup : registry -> string -> tool_def option

(** Execute a tool within a Cordis context, automatically recording revertible effects *)
val execute :
  registry ->
  name:string ->
  args:(string * string) list ->
  context:Dsh_core.Context.t ->
  tick:tick ->
  (tool_output, string) result

(** List all registered tools *)
val list_tools : registry -> tool_def list
