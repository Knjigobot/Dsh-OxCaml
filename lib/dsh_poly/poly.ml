(* poly.ml - Category Poly Implementation *)

module type INTERFACE = sig
  type pos
  type dir
end

type ('pos, 'dir) monomial = {
  positions : 'pos list;
  directions : 'pos -> 'dir list;
}

type ('p_pos, 'p_dir, 'q_pos, 'q_dir) lens = {
  fwd : 'p_pos -> 'q_pos;
  bwd : 'p_pos -> 'q_dir -> 'p_dir;
}

let id () : ('pos, 'dir, 'pos, 'dir) lens = {
  fwd = (fun p -> p);
  bwd = (fun _p d -> d);
}

let compose
    (l1 : ('p_pos, 'p_dir, 'q_pos, 'q_dir) lens)
    (l2 : ('q_pos, 'q_dir, 'r_pos, 'r_dir) lens) : ('p_pos, 'p_dir, 'r_pos, 'r_dir) lens =
  {
    fwd = (fun p -> l2.fwd (l1.fwd p));
    bwd = (fun p r_dir ->
      let q_pos = l1.fwd p in
      let q_dir = l2.bwd q_pos r_dir in
      l1.bwd p q_dir);
  }

let tensor
    (l1 : ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens)
    (l2 : ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens) :
    ('p_pos * 'q_pos, 'p_dir * 'q_dir, 'p2_pos * 'q2_pos, 'p2_dir * 'q2_dir) lens =
  {
    fwd = (fun (p, q) -> (l1.fwd p, l2.fwd q));
    bwd = (fun (p, q) (p2_dir, q2_dir) ->
      (l1.bwd p p2_dir, l2.bwd q q2_dir));
  }

let sum
    (l1 : ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens)
    (l2 : ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens) :
    (('p_pos, 'q_pos) Either.t, ('p_dir, 'q_dir) Either.t, ('p2_pos, 'q2_pos) Either.t, ('p2_dir, 'q2_dir) Either.t) lens =
  {
    fwd = (function
      | Either.Left p -> Either.Left (l1.fwd p)
      | Either.Right q -> Either.Right (l2.fwd q));
    bwd = (fun pos target_dir ->
      match pos, target_dir with
      | Either.Left p, Either.Left p2_d -> Either.Left (l1.bwd p p2_d)
      | Either.Right q, Either.Right q2_d -> Either.Right (l2.bwd q q2_d)
      | Either.Left p, Either.Right _ -> Either.Left (l1.bwd p (Obj.magic ()))
      | Either.Right q, Either.Left _ -> Either.Right (l2.bwd q (Obj.magic ())));
  }

type ('p_dir, 'q_dir) prod_dir =
  | Dir_left of 'p_dir
  | Dir_right of 'q_dir
  | Dir_both of 'p_dir * 'q_dir

let product
    (l1 : ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens)
    (l2 : ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens) :
    ('p_pos * 'q_pos, ('p_dir, 'q_dir) prod_dir, 'p2_pos * 'q2_pos, ('p2_dir, 'q2_dir) prod_dir) lens =
  {
    fwd = (fun (p, q) -> (l1.fwd p, l2.fwd q));
    bwd = (fun (p, q) -> function
      | Dir_left d2 -> Dir_left (l1.bwd p d2)
      | Dir_right d2 -> Dir_right (l2.bwd q d2)
      | Dir_both (dp, dq) -> Dir_both (l1.bwd p dp, l2.bwd q dq));
  }

type ('p_pos, 'q_pos) comp_pos = {
  outer_pos : 'p_pos;
  inner_pos : 'q_pos;
}

type ('p_dir, 'q_dir) comp_dir = {
  outer_dir : 'p_dir;
  inner_dir : 'q_dir;
}

let substitute
    (l1 : ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens)
    (l2 : ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens) :
    (('p_pos, 'q_pos) comp_pos, ('p_dir, 'q_dir) comp_dir, ('p2_pos, 'q2_pos) comp_pos, ('p2_dir, 'q2_dir) comp_dir) lens =
  {
    fwd = (fun c -> {
      outer_pos = l1.fwd c.outer_pos;
      inner_pos = l2.fwd c.inner_pos;
    });
    bwd = (fun c target_dir -> {
      outer_dir = l1.bwd c.outer_pos target_dir.outer_dir;
      inner_dir = l2.bwd c.inner_pos target_dir.inner_dir;
    });
  }

let is_lawful ~equal_pos ~equal_dir ~lens ~sample_pos ~sample_dir =
  List.for_all (fun p ->
    let fwd_p = lens.fwd p in
    equal_pos p fwd_p &&
    List.for_all (fun d ->
      let bwd_d = lens.bwd p d in
      equal_dir d bwd_d
    ) sample_dir
  ) sample_pos
