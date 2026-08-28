(** [Dsh_core.Types] - Strict Algebraic Types for Agent Harness & Lifecycles *)

type tick = int

type token_usage = {
  prompt_tokens : int;
  completion_tokens : int;
  total_cost_usd : float;
}

val zero_tokens : token_usage
val add_tokens : token_usage -> token_usage -> token_usage

type role =
  | System
  | User
  | Assistant
  | Tool_runner
  | Verifier

val string_of_role : role -> string

type message = {
  id : string;
  role : role;
  content : string;
  timestamp : float;
  token_count : int;
}

type agent_id = string

type agent_status =
  | Idle
  | Running of tick
  | Blocked of { reason : string; since_tick : tick }
  | Finished of { result : string; at_tick : tick }
  | Failed of { error : string; at_tick : tick }

val string_of_status : agent_status -> string

type rollback_token = {
  token_id : int;
  causal_tick : tick;
  revert_action : unit -> (unit, string) result;
}

type execution_trace = {
  tick : tick;
  agent_id : agent_id;
  action_name : string;
  duration_ms : float;
  tokens_spent : token_usage;
  rollback_available : bool;
}

type ('pos, 'err) transition_result =
  | Progress of { new_pos : 'pos; delta_tokens : token_usage; trace : string }
  | Blocked_on of { condition : string; retry_after_tick : tick }
  | Rejected of { diagnostic : 'err; rollback : rollback_token option }
