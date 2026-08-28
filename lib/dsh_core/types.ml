(* types.ml - Core Algebraic Types Implementation *)

type tick = int

type token_usage = {
  prompt_tokens : int;
  completion_tokens : int;
  total_cost_usd : float;
}

let zero_tokens = {
  prompt_tokens = 0;
  completion_tokens = 0;
  total_cost_usd = 0.0;
}

let add_tokens a b = {
  prompt_tokens = a.prompt_tokens + b.prompt_tokens;
  completion_tokens = a.completion_tokens + b.completion_tokens;
  total_cost_usd = a.total_cost_usd +. b.total_cost_usd;
}

type role =
  | System
  | User
  | Assistant
  | Tool_runner
  | Verifier

let string_of_role = function
  | System -> "system"
  | User -> "user"
  | Assistant -> "assistant"
  | Tool_runner -> "tool_runner"
  | Verifier -> "verifier"

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

let string_of_status = function
  | Idle -> "Idle"
  | Running t -> Printf.sprintf "Running(tick=%d)" t
  | Blocked b -> Printf.sprintf "Blocked(tick=%d, reason=%s)" b.since_tick b.reason
  | Finished f -> Printf.sprintf "Finished(tick=%d, res=%s)" f.at_tick f.result
  | Failed e -> Printf.sprintf "Failed(tick=%d, err=%s)" e.at_tick e.error

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
