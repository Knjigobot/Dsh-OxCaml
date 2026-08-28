(* main.ml - Dsh-OxCaml CLI Entrypoint *)

let print_banner () =
  print_endline "========================================================================";
  print_endline "  DSH-OXCAML: DeepSeek Agent Harness in OxCaml on Cordis Framework";
  print_endline "  Polynomial Functors (Poly), Categorical Cybernetics & Reversible Effects";
  print_endline "========================================================================"

let run_dst_demo () =
  print_endline "\n[*] Initializing Deterministic Simulation Testing (DST) Harness...";
  let sim1 = Dsh_eval.Dst.create_simulator ~seed:42 in
  let sim2 = Dsh_eval.Dst.create_simulator ~seed:42 in

  (* Schedule identical faults *)
  Dsh_eval.Dst.schedule_fault sim1 ~at_tick:2 ~fault:(Network_partition { duration_ticks = 1 });
  Dsh_eval.Dst.schedule_fault sim2 ~at_tick:2 ~fault:(Network_partition { duration_ticks = 1 });

  let step_fn tick =
    Ok (Printf.sprintf "Agent executed spatiotemporal step at tick %d" tick, {
      Dsh_core.Types.prompt_tokens = 20;
      completion_tokens = 10;
      total_cost_usd = 0.0001;
    })
  in

  print_endline "[*] Executing Simulation Run 1 (Seed 42)...";
  let res1 = Dsh_eval.Dst.run_simulation sim1 ~max_ticks:5 ~step_fn in
  print_endline "[*] Executing Simulation Run 2 (Seed 42)...";
  let res2 = Dsh_eval.Dst.run_simulation sim2 ~max_ticks:5 ~step_fn in

  match res1, res2 with
  | Ok (traces1, _), Ok (traces2, _) ->
    List.iter (fun tr -> print_endline ("    " ^ tr)) traces1;
    let is_deterministic = Dsh_eval.Dst.verify_replay_determinism traces1 traces2 in
    Printf.printf "\n[✓] Byte-for-byte Determinism Check: %s\n" (if is_deterministic then "PASSED (100% Identical)" else "FAILED");
  | Error e, _ | _, Error e ->
    Printf.printf "[!] Simulation failed: %s\n" e

let run_edgebench_demo () =
  print_endline "\n[*] Evaluating EdgeBench Log-Sigmoid Scaling Laws...";
  let flat_runs : Dsh_eval.Edgebench.data_point list = [
    { interaction_time = 1.0; performance_score = 0.10 };
    { interaction_time = 5.0; performance_score = 0.25 };
    { interaction_time = 15.0; performance_score = 0.45 };
    { interaction_time = 30.0; performance_score = 0.60 };
    { interaction_time = 60.0; performance_score = 0.75 };
    { interaction_time = 100.0; performance_score = 0.85 };
  ] in
  let poly_runs : Dsh_eval.Edgebench.data_point list = [
    { interaction_time = 1.0; performance_score = 0.20 };
    { interaction_time = 3.0; performance_score = 0.50 };
    { interaction_time = 6.0; performance_score = 0.75 };
    { interaction_time = 10.0; performance_score = 0.90 };
    { interaction_time = 15.0; performance_score = 0.96 };
  ] in
  match Dsh_eval.Edgebench.evaluate_poly_advantage ~flat_runs ~poly_runs with
  | Ok cmp ->
    Printf.printf "  - Flat Loop Scaling:  t_mid = %.1f steps, beta = %.2f\n" cmp.flat_scaling.t_mid cmp.flat_scaling.beta;
    Printf.printf "  - Poly Decomposition: t_mid = %.1f steps, beta = %.2f\n" cmp.poly_scaling.t_mid cmp.poly_scaling.beta;
    Printf.printf "  [✓] Speedup Factor to 90%% Accuracy: %.2fx faster\n" cmp.speedup_factor_at_90pct;
    Printf.printf "  [✓] Measured Inference Token Reduction: %.1f%%\n" cmp.token_reduction_pct;
  | Error err ->
    Printf.printf "[!] EdgeBench evaluation error: %s\n" err

let run_poly_agent_demo () =
  print_endline "\n[*] Running Hierarchical Polynomial Agent (p o q)...";
  let ctx = Dsh_core.Context.create_root "dsh_root" in

  (* Create Supervisor Agent P *)
  let supervisor = Dsh_core.Agent.create
    ~id:"architect_agent"
    ~initial_state:("initial_goal", 0)
    ~context:ctx
    ~readout:(fun (goal, _) -> goal)
    ~transition:(fun (goal, count) feedback _tick ->
      Ok ((feedback, count + 1), {
        Dsh_core.Types.prompt_tokens = 50;
        completion_tokens = 25;
        total_cost_usd = 0.0005;
      }))
  in

  (* Create Worker Agent Q *)
  let worker = Dsh_core.Agent.create
    ~id:"codegen_agent"
    ~initial_state:("idle", [])
    ~context:(Dsh_core.Context.isolate ~name:"worker_scope" ctx)
    ~readout:(fun (st, _) -> st)
    ~transition:(fun (_st, history) input_spec _tick ->
      Ok ((Printf.sprintf "synthesized_ast_for(%s)" input_spec, input_spec :: history), {
        Dsh_core.Types.prompt_tokens = 20;
        completion_tokens = 40;
        total_cost_usd = 0.0001;
      }))
  in

  (* Dependent Lens f : P -> Q *)
  let delegation_lens : (string, string, string, string) Dsh_poly.Poly.lens = {
    fwd = (fun sup_goal -> Printf.sprintf "spec_of(%s)" sup_goal);
    bwd = (fun sup_goal wkr_output -> Printf.sprintf "verified(%s, %s)" sup_goal wkr_output);
  } in

  let hierarchy = Dsh_core.Hierarchy.create_hierarchy ~supervisor ~worker ~delegation_lens in

  print_endline "  [>] Executing hierarchical step 1...";
  (match Dsh_core.Hierarchy.run_hierarchical_step hierarchy with
   | Progress { new_pos = (sup_p, wkr_p); delta_tokens = tok; trace } ->
     Printf.printf "  [✓] Supervisor State: %s\n" sup_p;
     Printf.printf "  [✓] Worker Result:     %s\n" wkr_p;
     Printf.printf "  [✓] Step Trace:        %s\n" trace;
     Printf.printf "  [✓] Tokens Consumed:   %d prompt, %d completion (Cost: $%.6f)\n"
       tok.prompt_tokens tok.completion_tokens tok.total_cost_usd;
   | Blocked_on b -> Printf.printf "  [!] Blocked: %s\n" b.condition
   | Rejected r -> Printf.printf "  [!] Rejected: %s\n" r.diagnostic);

  let total = Dsh_core.Hierarchy.aggregate_tokens hierarchy in
  Printf.printf "  [*] Total Cumulative Session Cost: $%.6f\n" total.total_cost_usd

let () =
  print_banner ();
  let args = Array.to_list Sys.argv in
  match args with
  | _ :: "dst" :: _ -> run_dst_demo ()
  | _ :: "eval" :: _ -> run_edgebench_demo ()
  | _ :: "agent" :: _ -> run_poly_agent_demo ()
  | _ ->
    run_poly_agent_demo ();
    run_dst_demo ();
    run_edgebench_demo ()
