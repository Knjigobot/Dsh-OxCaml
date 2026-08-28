(* test_dst.ml - Deterministic Simulation Testing replay tests *)

let test_simulation_replay () =
  let run_with_seed seed =
    let sim = Dsh_eval.Dst.create_simulator ~seed in
    Dsh_eval.Dst.schedule_fault sim ~at_tick:3 ~fault:(Clock_skew { offset_ticks = 2 });
    let step_fn tick =
      Ok (Printf.sprintf "action_%d" tick, Dsh_core.Types.zero_tokens)
    in
    Dsh_eval.Dst.run_simulation sim ~max_ticks:6 ~step_fn
  in
  let res1 = run_with_seed 101 in
  let res2 = run_with_seed 101 in
  match res1, res2 with
  | Ok (tr1, _), Ok (tr2, _) ->
    assert (Dsh_eval.Dst.verify_replay_determinism tr1 tr2 = true);
    assert (List.length tr1 = 6)
  | _ -> assert false

let test_prng_and_chaos_sweep () =
  (* Test PRNG determinism *)
  let prng1 = Dsh_eval.Dst.Prng.create ~seed:42 in
  let prng2 = Dsh_eval.Dst.Prng.create ~seed:42 in
  for _ = 1 to 20 do
    assert (Dsh_eval.Dst.Prng.next_u64 prng1 = Dsh_eval.Dst.Prng.next_u64 prng2);
    assert (Dsh_eval.Dst.Prng.next_float prng1 = Dsh_eval.Dst.Prng.next_float prng2);
  done;

  (* Test automated chaos sweep *)
  let config : Dsh_eval.Dst.chaos_config = {
    iterations = 5;
    max_ticks = 8;
    chaos_rate = 0.4;
  } in
  let step_fn tick =
    Ok (Printf.sprintf "chaos_step_%d" tick, Dsh_core.Types.zero_tokens)
  in
  match Dsh_eval.Dst.run_chaos_sweep ~seed:999 ~config ~step_fn with
  | Ok report ->
    assert (report.total_runs = 5);
    assert (report.deterministic_replays_verified = 5);
    assert (report.fault_count > 0)
  | Error err -> failwith err

let () =
  test_simulation_replay ();
  test_prng_and_chaos_sweep ();
  print_endline "[PASS] test_dst completed successfully."
