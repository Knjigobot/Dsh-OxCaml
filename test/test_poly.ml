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

let test_sum_lens () =
  let l1 : (int, string, string, int) Dsh_poly.Poly.lens = {
    fwd = string_of_int;
    bwd = (fun orig_int fb -> Printf.sprintf "L_%d_%d" orig_int fb);
  } in
  let l2 : (bool, float, string, bool) Dsh_poly.Poly.lens = {
    fwd = (fun b -> if b then "T" else "F");
    bwd = (fun orig_b fb -> if fb then 1.0 else 0.0);
  } in
  let sum_l = Dsh_poly.Poly.sum l1 l2 in
  assert (sum_l.fwd (Either.Left 42) = Either.Left "42");
  assert (sum_l.fwd (Either.Right true) = Either.Right "T");
  match sum_l.bwd (Either.Left 42) (Dsh_poly.Poly.Sum_left 99) with
  | Dsh_poly.Poly.Sum_left s -> assert (s = "L_42_99")
  | _ -> assert false

let () =
  test_id_lens ();
  test_lens_composition ();
  test_lawful_lens ();
  test_sum_lens ();
  print_endline "[PASS] test_poly completed successfully."
