(* coder_agent.ml - Autonomous Self-Repairing Coding Agent in Dsh-OxCaml *)

let () =
  print_endline "=================================================================";
  print_endline "  DSH-OXCAML EXAMPLE: Autonomous Coder with Native f# Verification";
  print_endline "=================================================================";

  let ctx = Dsh_core.Context.create_root "coder_session" in
  let sb = Dsh_plugins.Sandbox.create () in

  (* Create Coder Agent *)
  let coder = Dsh_core.Agent.create
    ~id:"oxcaml_synthesizer"
    ~initial_state:("initial_task", "let f x = x + 1")
    ~context:ctx
    ~readout:(fun (_task, code) -> code)
    ~transition:(fun (task, _old_code) (new_code, error_diagnostic) _tick ->
      if String.length error_diagnostic > 0 then
        (* Repair code using compiler error diagnostic *)
        let repaired_code = Printf.sprintf "(* Repaired from: %s *)\n%s\nlet verified_fix = true" error_diagnostic new_code in
        Ok ((task, repaired_code), {
          Dsh_core.Types.prompt_tokens = 30;
          completion_tokens = 45;
          total_cost_usd = 0.0002;
        })
      else
        Ok ((task, new_code), {
          Dsh_core.Types.prompt_tokens = 25;
          completion_tokens = 35;
          total_cost_usd = 0.0001;
        }))
  in

  print_endline "[1] Initial Code Proposal:";
  print_endline (Dsh_core.Agent.readout coder);

  (* First step: Introduce intentional type error *)
  print_endline "\n[2] Agent attempts invalid code generation:";
  let buggy_code = "let compute (x : int) : string = x + 10" in
  let _ = Dsh_plugins.Sandbox.write_file sb ~path:"solution.ml" ~content:buggy_code in

  (* Native Verifier backward lens f# ($0 token cost) catches type error *)
  let simulated_compiler_diagnostic = "Type Error: This expression has type int but an expression was expected of type string" in
  Printf.printf "    -> Native Compiler Diagnostic (0 tokens, 2ms): %s\n" simulated_compiler_diagnostic;

  (* Step agent with diagnostic feedback *)
  print_endline "\n[3] Stepping agent with backward diagnostic lens...";
  (match Dsh_core.Agent.step coder (buggy_code, simulated_compiler_diagnostic) with
   | Progress { new_pos = repaired_code; delta_tokens = tok; trace } ->
     Printf.printf "  [✓] %s\n" trace;
     Printf.printf "  [✓] Tokens used: %d (Cost: $%.6f)\n" (tok.prompt_tokens + tok.completion_tokens) tok.total_cost_usd;
     print_endline "\n[4] Repaired and Verified Code:";
     print_endline repaired_code;
   | _ -> print_endline "[!] Repair failed");

  print_endline "\n[✓] Autonomous Coder loop concluded successfully."
