open Dsh_core.Types

module Prng = struct
  type t = {
    mutable state : int64;
  }

  let create ~seed = {
    state = Int64.of_int (if seed = 0 then 0x12345678 else seed);
  }

  (* SplitMix64 deterministic pseudo-random generator *)
  let next_u64 (p : t) : int64 =
    let open Int64 in
    p.state <- add p.state 0x9e3779b97f4a7c15L;
    let z = p.state in
    let z = mul (logxor z (shift_right_logical z 30)) 0xbf58476d1ce4e5b9L in
    let z = mul (logxor z (shift_right_logical z 27)) 0x94d049bb133111ebL in
    logxor z (shift_right_logical z 31)

  let next_float (p : t) : float =
    let u = next_u64 p in
    let pos_u = Int64.logand u 0x7fffffffffffffffL in
    Int64.to_float pos_u /. 9223372036854775807.0

  let next_int (p : t) ~max : int =
    if max <= 1 then 0
    else
      let f = next_float p in
      int_of_float (f *. float_of_int max)
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

type simulator = {
  seed : int;
  prng : Prng.t;
  mutable current_tick : tick;
  scheduled_faults : (tick, fault_type) Hashtbl.t;
}

let create_simulator ~seed = {
  seed;
  prng = Prng.create ~seed;
  current_tick = 0;
  scheduled_faults = Hashtbl.create 32;
}

let schedule_fault sim ~at_tick ~fault =
  Hashtbl.replace sim.scheduled_faults at_tick fault

let schedule_random_faults sim ~rate ~max_ticks =
  for t = 1 to max_ticks do
    let roll = Prng.next_float sim.prng in
    if roll < rate then
      let ftype_idx = Prng.next_int sim.prng ~max:4 in
      let fault = match ftype_idx with
        | 0 -> Network_partition { duration_ticks = 1 + Prng.next_int sim.prng ~max:3 }
        | 1 -> Clock_skew { offset_ticks = 1 + Prng.next_int sim.prng ~max:5 }
        | 2 -> Disk_corruption
        | _ -> LLM_rate_limit { retry_after_ticks = 1 + Prng.next_int sim.prng ~max:2 }
      in
      schedule_fault sim ~at_tick:t ~fault
  done

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

let run_chaos_sweep ~seed ~(config : chaos_config) ~step_fn =
  let verified_replays = ref 0 in
  let total_faults = ref 0 in
  let total_tokens = ref zero_tokens in

  for iter = 1 to config.iterations do
    let sim_seed = seed + iter in
    (* Run 1 *)
    let sim1 = create_simulator ~seed:sim_seed in
    schedule_random_faults sim1 ~rate:config.chaos_rate ~max_ticks:config.max_ticks;
    let fault_cnt1 = Hashtbl.length sim1.scheduled_faults in
    total_faults := !total_faults + fault_cnt1;

    (* Run 2 with identical seed *)
    let sim2 = create_simulator ~seed:sim_seed in
    schedule_random_faults sim2 ~rate:config.chaos_rate ~max_ticks:config.max_ticks;

    match run_simulation sim1 ~max_ticks:config.max_ticks ~step_fn,
          run_simulation sim2 ~max_ticks:config.max_ticks ~step_fn with
    | Ok (tr1, tok1), Ok (tr2, _) ->
      if verify_replay_determinism tr1 tr2 then
        incr verified_replays;
      total_tokens := add_tokens !total_tokens tok1
    | _ -> ()
  done;

  Ok {
    total_runs = config.iterations;
    deterministic_replays_verified = !verified_replays;
    fault_count = !total_faults;
    avg_tokens = !total_tokens;
  }
