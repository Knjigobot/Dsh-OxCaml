(* test_sandbox.ml - Unit tests for Sandbox & Reversible Tool Hooks *)

let test_virtual_sandbox () =
  let sb = Dsh_plugins.Sandbox.create () in
  assert (Dsh_plugins.Sandbox.write_file sb ~path:"hello.ml" ~content:"let x = 42" = Ok ());
  assert (Dsh_plugins.Sandbox.exists sb ~path:"hello.ml" = true);
  assert (Dsh_plugins.Sandbox.read_file sb ~path:"hello.ml" = Ok "let x = 42");

  (* Snapshot & restore *)
  let snap = Dsh_plugins.Sandbox.snapshot sb in
  assert (Dsh_plugins.Sandbox.remove_file sb ~path:"hello.ml" = Ok ());
  assert (Dsh_plugins.Sandbox.exists sb ~path:"hello.ml" = false);
  Dsh_plugins.Sandbox.restore sb snap;
  assert (Dsh_plugins.Sandbox.exists sb ~path:"hello.ml" = true)

let test_reversible_tool_execution () =
  let ctx = Dsh_core.Context.create_root "test_tool_ctx" in
  let reg = Dsh_plugins.Tool.create_registry () in
  let file_state = ref "original" in
  let tool_def : Dsh_plugins.Tool.tool_def = {
    name = "mutate_file";
    description = "Modifies a file buffer with reversible rollback";
    parameters = [
      { name = "content"; ptype = String_t; description = "New file content"; required = true };
    ];
    handler = (fun args _c ->
      let new_content = List.assoc "content" args in
      let old_val = !file_state in
      file_state := new_content;
      Ok {
        stdout_data = "mutated";
        stderr_data = "";
        exit_code = 0;
        rollback_hook = Some (fun () ->
          file_state := old_val;
          Ok ());
      });
  } in
  Dsh_plugins.Tool.register reg tool_def;

  (* Execute tool *)
  let res = Dsh_plugins.Tool.execute reg ~name:"mutate_file" ~args:[("content", "mutated_value")] ~context:ctx ~tick:1 in
  assert (Result.is_ok res);
  assert (!file_state = "mutated_value");
  assert (Dsh_core.Context.effect_count ctx = 1);

  (* Rollback effect stack *)
  let rb_res = Dsh_core.Context.rollback_all ctx in
  assert (Result.is_ok rb_res);
  assert (!file_state = "original");
  assert (Dsh_core.Context.effect_count ctx = 0)

let test_shell_lexer_and_eval () =
  let sb = Dsh_plugins.Sandbox.create () in
  (* Test tokenizing quoted paths *)
  match Dsh_plugins.Sandbox.tokenize_command "cat \"path with spaces.txt\" 'another arg'" with
  | Ok tokens ->
    assert (tokens = ["cat"; "path with spaces.txt"; "another arg"])
  | Error _ -> assert false;

  (* Test eval_command with quoted filenames *)
  let _ = Dsh_plugins.Sandbox.write_file sb ~path:"my test script.ml" ~content:"print_endline \"ok\"" in
  match Dsh_plugins.Sandbox.eval_command sb "cat \"my test script.ml\"" with
  | Ok (0, out, "") -> assert (out = "print_endline \"ok\"")
  | _ -> assert false;

  (* Test unclosed quote detection *)
  match Dsh_plugins.Sandbox.tokenize_command "cat \"unclosed string" with
  | Error err -> assert (String.length err > 0)
  | Ok _ -> assert false

let () =
  test_virtual_sandbox ();
  test_reversible_tool_execution ();
  test_shell_lexer_and_eval ();
  print_endline "[PASS] test_sandbox completed successfully."
