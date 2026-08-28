(* test_poly.ml - Unit tests for Category Poly & Lenses *)

let test_id_lens () =
  let l = Dsh_poly.Poly.id () in
  assert (l.fwd 42 = 42);
  assert (l.bwd 42 "resp" = "resp")

let test_lens_composition () =
  let l1 : (int, string, string, int) Dsh_poly.Poly.lens = {
    fwd = string_of_int;
    bwd = (fun orig_int int_feedback -> Printf.sprintf "%d_%d" orig_int int_feedback);
  } in
  let l2 : (string, int, bool, float) Dsh_poly.Poly.lens = {
    fwd = (fun s -> String.length s > 0);
    bwd = (fun s flt_feedback -> String.length s + int_of_float flt_feedback);
  } in
  let composed = Dsh_poly.Poly.compose l1 l2 in
  assert (composed.fwd 123 = true);
  let feedback = composed.bwd 123 4.5 in
  assert (feedback = "123_7")

let test_lawful_lens () =
  let l = Dsh_poly.Poly.id () in
  let is_valid = Dsh_poly.Poly.is_lawful
    ~equal_pos:(=)
    ~equal_dir:(=)
    ~lens:l
    ~sample_pos:[1; 2; 3; 100]
    ~sample_dir:["a"; "b"; "c"]
  in
  assert is_valid

let () =
  test_id_lens ();
  test_lens_composition ();
  test_lawful_lens ();
  print_endline "[PASS] test_poly completed successfully."
