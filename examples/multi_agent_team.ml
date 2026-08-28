(* multi_agent_team.ml - 3-Tier Multi-Agent Team Topology in Dsh-OxCaml *)

let () =
  print_endline "=================================================================";
  print_endline "  DSH-OXCAML EXAMPLE: 3-Tier Multi-Agent Team (Architect -> Coder -> Tester)";
  print_endline "=================================================================";

  let root_ctx = Dsh_core.Context.create_root "team_topology" in

  (* Agent 1: Architect (P) *)
  let architect = Dsh_core.Agent.create
    ~id:"architect"
    ~initial_state:"Spec: Real-time Order Matching Engine"
    ~context:root_ctx
    ~readout:(fun spec -> spec)
    ~transition:(fun _prev feedback _tick ->
      Ok (Printf.sprintf "Architect approved: %s" feedback, {
        Dsh_core.Types.prompt_tokens = 60;
        completion_tokens = 30;
        total_cost_usd = 0.0006;
      }))
  in

  (* Agent 2: Coder (Q) *)
  let coder = Dsh_core.Agent.create
    ~id:"coder"
    ~initial_state:"module MatchingEngine = struct end"
    ~context:(Dsh_core.Context.isolate ~name:"coder_ctx" root_ctx)
    ~readout:(fun code -> code)
    ~transition:(fun _prev (spec, test_feedback) _tick ->
      let new_code = Printf.sprintf "(* Built for: %s *)\nlet match_orders book = [%s]" spec test_feedback in
      Ok (new_code, {
        Dsh_core.Types.prompt_tokens = 40;
        completion_tokens = 50;
        total_cost_usd = 0.0003;
      }))
  in

  (* Agent 3: Tester (R) *)
  let tester = Dsh_core.Agent.create
    ~id:"tester"
    ~initial_state:"All 12 invariant tests passing"
    ~context:(Dsh_core.Context.isolate ~name:"tester_ctx" root_ctx)
    ~readout:(fun report -> report)
    ~transition:(fun _prev code _tick ->
      let report = if String.contains code "match_orders" then "100% test coverage passed" else "tests failed" in
      Ok (report, {
        Dsh_core.Types.prompt_tokens = 15;
        completion_tokens = 15;
        total_cost_usd = 0.00005;
      }))
  in

  print_endline "[*] Step 1: Architect emits system specification:";
  let spec = Dsh_core.Agent.readout architect in
  Printf.printf "    %s\n" spec;

  print_endline "\n[*] Step 2: Coder synthesizes initial implementation:";
  let _ = Dsh_core.Agent.step coder (spec, "initial") in
  let code = Dsh_core.Agent.readout coder in
  Printf.printf "    %s\n" code;

  print_endline "\n[*] Step 3: Tester executes property checks (f# backward feedback):";
  let _ = Dsh_core.Agent.step tester code in
  let test_report = Dsh_core.Agent.readout tester in
  Printf.printf "    %s\n" test_report;

  print_endline "\n[*] Step 4: Backward feedback routes back to Architect:";
  let _ = Dsh_core.Agent.step architect test_report in
  let final_status = Dsh_core.Agent.readout architect in
  Printf.printf "    %s\n" final_status;

  let total_cost =
    (Dsh_core.Agent.total_tokens architect).total_cost_usd +.
    (Dsh_core.Agent.total_tokens coder).total_cost_usd +.
    (Dsh_core.Agent.total_tokens tester).total_cost_usd
  in
  Printf.printf "\n[✓] 3-Tier Multi-Agent Session Finished with Total Cost: $%.6f\n" total_cost
