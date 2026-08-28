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

let () =
  test_simulation_replay ();
  print_endline "[PASS] test_dst completed successfully."
