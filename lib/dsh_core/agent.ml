(* agent.ml - Polynomial Coalgebraic Agent State Machine Implementation *)

open Types

type ('state, 'pos, 'dir) t = {
  id : agent_id;
  mutable state : 'state;
  mutable tick : tick;
  mutable status : agent_status;
  mutable tokens : token_usage;
  context : Context.t;
  readout_fn : 'state -> 'pos;
  transition_fn : 'state -> 'dir -> tick -> ('state * token_usage, string) result;
  mutable history : (tick * 'state * execution_trace) list;
}

let create ~id ~initial_state ~context ~readout ~transition = {
  id;
  state = initial_state;
  tick = 0;
  status = Idle;
  tokens = zero_tokens;
  context;
  readout_fn = readout;
  transition_fn = transition;
  history = [];
}

let id a = a.id
let current_tick a = a.tick
let status a = a.status
let total_tokens a = a.tokens
let context a = a.context

let readout a = a.readout_fn a.state

let step (a : ('state, 'pos, 'dir) t) (stimulus : 'dir) =
  let next_tick = a.tick + 1 in
  let start_time = Unix.gettimeofday () in
  a.status <- Running next_tick;
  match a.transition_fn a.state stimulus next_tick with
  | Ok (new_state, delta_tok) ->
    let end_time = Unix.gettimeofday () in
    let duration = (end_time -. start_time) *. 1000.0 in
    let trace_item = {
      tick = next_tick;
      agent_id = a.id;
      action_name = Printf.sprintf "step_%d" next_tick;
      duration_ms = duration;
      tokens_spent = delta_tok;
      rollback_available = true;
    } in
    a.history <- (a.tick, a.state, trace_item) :: a.history;
    a.state <- new_state;
    a.tick <- next_tick;
    a.tokens <- add_tokens a.tokens delta_tok;
    let new_pos = a.readout_fn new_state in
    a.status <- Idle;
    Progress {
      new_pos;
      delta_tokens = delta_tok;
      trace = Printf.sprintf "[%s] Tick %d completed in %.2fms" a.id next_tick duration;
    }
  | Error err ->
    a.status <- Failed { error = err; at_tick = next_tick };
    let rb_token = Context.register_effect a.context ~tick:next_tick ~label:(Printf.sprintf "step_fail_%d" next_tick) (fun () ->
      Ok ()
    ) in
    Rejected {
      diagnostic = err;
      rollback = Some rb_token;
    }

let traces a =
  List.map (fun (_, _, tr) -> tr) (List.rev a.history)

let rollback_to_tick (a : ('state, 'pos, 'dir) t) target_tick =
  if target_tick > a.tick then
    Error (Printf.sprintf "Cannot rollback forward to tick %d from current tick %d" target_tick a.tick)
  else if target_tick = a.tick then
    Ok ()
  else
    match List.find_opt (fun (t, _, _) -> t = target_tick) a.history with
    | Some (_, saved_state, _) ->
      a.state <- saved_state;
      a.tick <- target_tick;
      a.history <- List.filter (fun (t, _, _) -> t <= target_tick) a.history;
      a.status <- Idle;
      Ok ()
    | None ->
      Error (Printf.sprintf "Target tick %d not found in execution history" target_tick)
