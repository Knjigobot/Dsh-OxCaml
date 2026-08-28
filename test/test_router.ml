(* test_router.ml - Unit tests for GBNF compiler & Llama provider *)

let test_gbnf_compilation () =
  let adt_def : Dsh_plugins.Gbnf.adt_def = {
    type_name = "transition";
    constructors = [
      { name = "Progress"; args = [("new_pos", G_String); ("telemetry", G_String)] };
      { name = "Blocked"; args = [("reason", G_String)] };
      { name = "Rejected"; args = [("err", G_String)] };
    ];
  } in
  let gbnf = Dsh_plugins.Gbnf.compile_adt_to_gbnf adt_def in
  assert (String.contains gbnf "Progress");
  assert (String.contains gbnf "Blocked");
  assert (String.contains gbnf "Rejected");

  let enum_rule = Dsh_plugins.Gbnf.compile_enum_to_gbnf ~rule_name:"role" ["system"; "user"; "assistant"] in
  assert (String.contains enum_rule "system");
  assert (Dsh_plugins.Gbnf.matches_enum ["system"; "user"; "assistant"] "user" = true);
  assert (Dsh_plugins.Gbnf.matches_enum ["system"; "user"; "assistant"] "invalid_role" = false)

let test_llama_provider_and_kv_fork () =
  let cfg : Dsh_plugins.Model_router.llama_config = {
    model_path = "/models/deepseek-coder-7b.Q4_K_M.gguf";
    n_threads = 8;
    n_gpu_layers = 33;
    context_size = 8192;
  } in
  let llama = Dsh_plugins.Model_router.create_llama_provider ~config:cfg in

  (* Test KV cache sequence forking *)
  assert (Dsh_plugins.Model_router.fork_kv_cache ~seq_src:0 ~seq_dst:1 = Ok ());

  let req : Dsh_plugins.Model_router.generation_request = {
    tier = Local_verifier;
    system_prompt = "You are a typed verifier.";
    messages = [];
    max_tokens = 64;
    temperature = 0.0;
    grammar = Some "root ::= (\"OK\" | \"FAIL\")";
  } in
  match llama req with
  | Ok resp ->
    assert (resp.tokens.total_cost_usd = 0.0);
    assert (String.length resp.content > 0)
  | Error err -> failwith err

let () =
  test_gbnf_compilation ();
  test_llama_provider_and_kv_fork ();
  print_endline "[PASS] test_router completed successfully."
