(* dst.ml - Deterministic Simulation Testing (DST) Implementation *)

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

type simulator = {
  seed : int;
  mutable current_tick : tick;
  scheduled_faults : (tick, fault_type) Hashtbl.t;
}

let create_simulator ~seed = {
  seed;
  current_tick = 0;
  scheduled_faults = Hashtbl.create 32;
}

let schedule_fault sim ~at_tick ~fault =
  Hashtbl.replace sim.scheduled_faults at_tick fault

let step_simulation sim =
  sim.current_tick <- sim.current_tick + 1;
  sim.current_tick

let current_tick sim = sim.current_tick

let run_simulation sim ~max_ticks ~step_fn =
  let traces = ref [] in
  let total_tok = ref zero_tokens in
  let rec loop () =
    if sim.current_tick >= max_ticks then
      Ok (List.rev !traces, !total_tok)
    else
      let t = step_simulation sim in
      match Hashtbl.find_opt sim.scheduled_faults t with
      | Some fault ->
        let fault_str = match fault with
          | Network_partition np -> Printf.sprintf "FAULT: NetworkPartition(dur=%d)" np.duration_ticks
          | Clock_skew cs -> Printf.sprintf "FAULT: ClockSkew(offset=%d)" cs.offset_ticks
          | Disk_corruption -> "FAULT: DiskCorruption"
          | LLM_rate_limit rl -> Printf.sprintf "FAULT: RateLimit(retry=%d)" rl.retry_after_ticks
        in
        traces := (Printf.sprintf "[Tick %d] %s" t fault_str) :: !traces;
        loop ()
      | None ->
        (match step_fn t with
         | Ok (trace_msg, tok) ->
           traces := (Printf.sprintf "[Tick %d] OK: %s" t trace_msg) :: !traces;
           total_tok := add_tokens !total_tok tok;
           loop ()
         | Error err ->
           traces := (Printf.sprintf "[Tick %d] ERROR: %s" t err) :: !traces;
           Error (Printf.sprintf "Simulation aborted at tick %d: %s" t err))
  in
  loop ()

let verify_replay_determinism trace1 trace2 =
  List.length trace1 = List.length trace2 &&
  List.for_all2 String.equal trace1 trace2
