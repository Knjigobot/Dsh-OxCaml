(** [Dsh_poly.Poly] - Polynomial Functors & Dependent Lenses
    Formalizes the Category Poly: interfaces as polynomials p(y) = Sum_{i in p(1)} y^{p[i]}
    and morphisms as dependent bidirectional lenses. *)

(** Abstract signature for a polynomial interface object *)
module type INTERFACE = sig
  type pos (** Positions / Visible states / Proposals emitted *)
  type dir (** Directions / Inputs / Feedback / Diagnostics accepted *)
end

(** Monomial interface representation p(y) = A * y^B *)
type ('pos, 'dir) monomial = {
  positions : 'pos list;
  directions : 'pos -> 'dir list;
}

(** A Dependent Lens morphism between polynomial interface P and Q: f : P -> Q *)
type ('p_pos, 'p_dir, 'q_pos, 'q_dir) lens = {
  fwd : 'p_pos -> 'q_pos;
  bwd : 'p_pos -> 'q_dir -> 'p_dir;
}

(** Identity lens on interface P *)
val id : unit -> ('pos, 'dir, 'pos, 'dir) lens

(** Lens composition (g o f):
    (g o f)_1 = g_1 o f_1
    (g o f)#(i, delta_r) = f#(i, g#(f_1(i), delta_r)) *)
val compose :
  ('p_pos, 'p_dir, 'q_pos, 'q_dir) lens ->
  ('q_pos, 'q_dir, 'r_pos, 'r_dir) lens ->
  ('p_pos, 'p_dir, 'r_pos, 'r_dir) lens

(** Dirichlet Tensor Product (P (x) Q):
    Synchronous parallel execution where both interfaces output simultaneously
    and require paired inputs. *)
val tensor :
  ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens ->
  ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens ->
  ('p_pos * 'q_pos, 'p_dir * 'q_dir, 'p2_pos * 'q2_pos, 'p2_dir * 'q2_dir) lens

(** Polynomial Sum (P + Q):
    Branching / Choice where system acts as either P or Q. *)
val sum :
  ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens ->
  ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens ->
  (('p_pos, 'q_pos) Either.t, ('p_dir, 'q_dir) Either.t, ('p2_pos, 'q2_pos) Either.t, ('p2_dir, 'q2_dir) Either.t) lens

(** Parallel Product (P * Q):
    Independent outputs; input to either updates that specific subsystem. *)
type ('p_dir, 'q_dir) prod_dir =
  | Dir_left of 'p_dir
  | Dir_right of 'q_dir
  | Dir_both of 'p_dir * 'q_dir

val product :
  ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens ->
  ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens ->
  ('p_pos * 'q_pos, ('p_dir, 'q_dir) prod_dir, 'p2_pos * 'q2_pos, ('p2_dir, 'q2_dir) prod_dir) lens

(** Hierarchical Polynomial Composition / Substitution (P o Q):
    Positions of P are substituted by instances of Q. *)
type ('p_pos, 'q_pos) comp_pos = {
  outer_pos : 'p_pos;
  inner_pos : 'q_pos;
}

type ('p_dir, 'q_dir) comp_dir = {
  outer_dir : 'p_dir;
  inner_dir : 'q_dir;
}

val substitute :
  ('p_pos, 'p_dir, 'p2_pos, 'p2_dir) lens ->
  ('q_pos, 'q_dir, 'q2_pos, 'q2_dir) lens ->
  (('p_pos, 'q_pos) comp_pos, ('p_dir, 'q_dir) comp_dir, ('p2_pos, 'q2_pos) comp_pos, ('p2_dir, 'q2_dir) comp_dir) lens

(** Lawful Lens validation:
    Verifies that identity feedback is preserved under round-tripping. *)
val is_lawful :
  equal_pos:('pos -> 'pos -> bool) ->
  equal_dir:('dir -> 'dir -> bool) ->
  lens:('pos, 'dir, 'pos, 'dir) lens ->
  sample_pos:'pos list ->
  sample_dir:'dir list ->
  bool
