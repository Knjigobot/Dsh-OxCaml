(** [Dsh_core.Agent] - Polynomial Coalgebraic Agent State Machine
    Implements discrete causal time stepping tau in Nat, deterministic replay, and state transitions. *)

open Types

type ('state, 'pos, 'dir) t

(** Create a new coalgebraic agent node *)
val create :
  id:agent_id ->
  initial_state:'state ->
  context:Context.t ->
  readout:('state -> 'pos) ->
  transition:('state -> 'dir -> tick -> ('state * token_usage, string) result) ->
  ('state, 'pos, 'dir) t

val id : ('state, 'pos, 'dir) t -> agent_id
val current_tick : ('state, 'pos, 'dir) t -> tick
val status : ('state, 'pos, 'dir) t -> agent_status
val total_tokens : ('state, 'pos, 'dir) t -> token_usage
val context : ('state, 'pos, 'dir) t -> Context.t

(** Read out current forward position / visible proposal (p(1)) *)
val readout : ('state, 'pos, 'dir) t -> 'pos

(** Execute one causal step with direction / input stimulus p[i] *)
val step :
  ('state, 'pos, 'dir) t ->
  'dir ->
  ('pos, string) transition_result

(** Retrieve execution history traces *)
val traces : ('state, 'pos, 'dir) t -> execution_trace list

(** Rollback to state at specific tick tau *)
val rollback_to_tick :
  ('state, 'pos, 'dir) t ->
  tick ->
  (unit, string) result
