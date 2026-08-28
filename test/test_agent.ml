(* test_agent.ml - Unit tests for Coalgebraic Agent State Machine & Reversible Effects *)

let test_agent_stepping_and_rollback () =
  let ctx = Dsh_core.Context.create_root "test_agent_ctx" in
  let agent = Dsh_core.Agent.create
    ~id:"test_worker"
    ~initial_state:0
    ~context:ctx
    ~readout:(fun s -> Printf.sprintf "state_%d" s)
    ~transition:(fun s dir _tick ->
      Ok (s + dir, {
        Dsh_core.Types.prompt_tokens = 10;
        completion_tokens = 5;
        total_cost_usd = 0.0001;
      }))
  in
  assert (Dsh_core.Agent.readout agent = "state_0");
  assert (Dsh_core.Agent.current_tick agent = 0);

  (* Step 1 *)
  (match Dsh_core.Agent.step agent 5 with
   | Progress { new_pos; _ } -> assert (new_pos = "state_5")
   | _ -> assert false);
  assert (Dsh_core.Agent.current_tick agent = 1);

  (* Step 2 *)
  (match Dsh_core.Agent.step agent 10 with
   | Progress { new_pos; _ } -> assert (new_pos = "state_15")
   | _ -> assert false);
  assert (Dsh_core.Agent.current_tick agent = 2);

  (* Rollback to tick 1 *)
  (match Dsh_core.Agent.rollback_to_tick agent 1 with
   | Ok () ->
     assert (Dsh_core.Agent.current_tick agent = 1);
     assert (Dsh_core.Agent.readout agent = "state_5")
   | Error e -> failwith e);

  (* Total token check *)
  let tokens = Dsh_core.Agent.total_tokens agent in
  assert (tokens.prompt_tokens = 20);
  assert (tokens.completion_tokens = 10)

let () =
  test_agent_stepping_and_rollback ();
  print_endline "[PASS] test_agent completed successfully."
