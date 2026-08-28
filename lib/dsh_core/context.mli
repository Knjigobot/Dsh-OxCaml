(** [Dsh_core.Context] - Spatial Coeffects & Revertible Disposal Stack
    Encapsulates isolated hierarchical namespaces, GADT service registry, and reverse causal disposal. *)

open Types

type 'a key = ..

type any_key = Key : 'a key -> any_key

type t

(** Create a new root context *)
val create_root : string -> t

(** Isolate a child context branching from a parent *)
val isolate : ?name:string -> t -> t

val name : t -> string
val parent : t -> t option

(** Provide a typed GADT service *)
val provide : t -> 'a key -> 'a -> unit

(** Inject a typed service from current or parent context *)
val inject : t -> 'a key -> 'a option

(** Dynamic store for string-keyed objects *)
val set_dynamic : t -> string -> Obj.t -> unit
val get_dynamic : t -> string -> Obj.t option

(** Register a revertible effect / disposal handler.
    When a branch fails or context is rolled back, cleanups run in reverse order (LIFO). *)
val register_effect : t -> tick:tick -> label:string -> (unit -> (unit, string) result) -> rollback_token

(** Rollback all registered revertible effects in reverse causal order *)
val rollback_all : t -> (int * string list, string) result

(** Count active registered effects *)
val effect_count : t -> int
