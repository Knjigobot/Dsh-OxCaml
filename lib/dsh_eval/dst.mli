(** [Dsh_eval.Dst] - Deterministic Simulation Testing (DST) Harness
    Enables single-threaded, 100% reproducible multi-agent execution with fault injection. *)

open Dsh_core.Types

type fault_type =
  | Network_partition of { duration_ticks : int }
  | Clock_skew of { offset_ticks : int }
  | Disk_corruption
  | LLM_rate_limit of { retry_after_ticks : int }

type simulation_event = {
  at_tick : tick;
  event_name : string;
  fault : fault_type option;
}

type simulator

val create_simulator : seed:int -> simulator

(** Schedule a simulation event / fault *)
val schedule_fault : simulator -> at_tick:tick -> fault:fault_type -> unit

(** Advance virtual simulation time by 1 tick *)
val step_simulation : simulator -> tick

val current_tick : simulator -> tick

(** Execute a deterministic simulation run and return serialized execution fingerprint *)
val run_simulation :
  simulator ->
  max_ticks:int ->
  step_fn:(tick -> (string * token_usage, string) result) ->
  (string list * token_usage, string) result

(** Compare two execution traces for byte-for-byte equivalence *)
val verify_replay_determinism : string list -> string list -> bool
