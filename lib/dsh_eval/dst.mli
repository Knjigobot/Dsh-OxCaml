(** [Dsh_eval.Dst] - Deterministic Simulation Testing (DST) Harness
    Enables single-threaded, 100% reproducible multi-agent execution with fault injection. *)

open Dsh_core.Types

module Prng : sig
  type t
  val create : seed:int -> t
  val next_u64 : t -> int64
  val next_float : t -> float
  val next_int : t -> max:int -> int
end

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

(** Automatically schedule randomized chaos faults using the simulator's deterministic PRNG *)
val schedule_random_faults : simulator -> rate:float -> max_ticks:int -> unit

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

type chaos_config = {
  iterations : int;
  max_ticks : int;
  chaos_rate : float;
}

type chaos_report = {
  total_runs : int;
  deterministic_replays_verified : int;
  fault_count : int;
  avg_tokens : token_usage;
}

(** Run an automated chaos fuzzing sweep verifying that repeated runs from the same seed are 100% byte-for-byte identical *)
val run_chaos_sweep :
  seed:int ->
  config:chaos_config ->
  step_fn:(tick -> (string * token_usage, string) result) ->
  (chaos_report, string) result
