(** [Dsh_core.Hierarchy] - Hierarchical Polynomial Decomposition (p o q)
    Decomposes monolithic state spaces into nested sub-polynomials to eliminate
    the EdgeBench logarithmic scaling barrier and localize error routing. *)

open Types

type ('sup_state, 'sup_pos, 'sup_dir, 'wkr_state, 'wkr_pos, 'wkr_dir) hierarchy_node

(** Create a 2-tier hierarchical agent system:
    - Supervisor operates on polynomial interface P
    - Worker operates on polynomial interface Q
    - Delegation is wired via a dependent lens f : P -> Q *)
val create_hierarchy :
  supervisor:('sup_state, 'sup_pos, 'sup_dir) Agent.t ->
  worker:('wkr_state, 'wkr_pos, 'wkr_dir) Agent.t ->
  delegation_lens:('sup_pos, 'sup_dir, 'wkr_dir, 'wkr_pos) Dsh_poly.Poly.lens ->
  ('sup_state, 'sup_pos, 'sup_dir, 'wkr_state, 'wkr_pos, 'wkr_dir) hierarchy_node

(** Execute a hierarchical turn:
    1. Supervisor emits high-level proposal i in P(1)
    2. Lens f1 maps proposal to Worker input in Q[f1(i)]
    3. Worker steps locally to produce result in Q(1)
    4. Dependent backward lens f# translates Worker result back into Supervisor co-state P[i]
    5. Supervisor updates state with zero context bleed *)
val run_hierarchical_step :
  ('sup_state, 'sup_pos, 'sup_dir, 'wkr_state, 'wkr_pos, 'wkr_dir) hierarchy_node ->
  (('sup_pos * 'wkr_pos), string) transition_result

(** Total token economics for hierarchical system *)
val aggregate_tokens :
  ('sup_state, 'sup_pos, 'sup_dir, 'wkr_state, 'wkr_pos, 'wkr_dir) hierarchy_node ->
  token_usage
