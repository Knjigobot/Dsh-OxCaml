(* hierarchy.ml - Hierarchical Polynomial Decomposition (p o q) Implementation *)

open Types

type ('sup_state, 'sup_pos, 'sup_dir, 'wkr_state, 'wkr_pos, 'wkr_dir) hierarchy_node = {
  supervisor : ('sup_state, 'sup_pos, 'sup_dir) Agent.t;
  worker : ('wkr_state, 'wkr_pos, 'wkr_dir) Agent.t;
  delegation_lens : ('sup_pos, 'sup_dir, 'wkr_dir, 'wkr_pos) Dsh_poly.Poly.lens;
}

let create_hierarchy ~supervisor ~worker ~delegation_lens = {
  supervisor;
  worker;
  delegation_lens;
}

let run_hierarchical_step (node : ('sup_state, 'sup_pos, 'sup_dir, 'wkr_state, 'wkr_pos, 'wkr_dir) hierarchy_node) =
  let sup_pos = Agent.readout node.supervisor in
  let wkr_input = node.delegation_lens.fwd sup_pos in
  match Agent.step node.worker wkr_input with
  | Progress { new_pos = wkr_output; delta_tokens = wkr_tok; trace = wkr_tr } ->
    let sup_feedback = node.delegation_lens.bwd sup_pos wkr_output in
    (match Agent.step node.supervisor sup_feedback with
     | Progress { new_pos = new_sup_pos; delta_tokens = sup_tok; trace = sup_tr } ->
       Progress {
         new_pos = (new_sup_pos, wkr_output);
         delta_tokens = add_tokens wkr_tok sup_tok;
         trace = Printf.sprintf "%s -> %s" wkr_tr sup_tr;
       }
     | Blocked_on b -> Blocked_on b
     | Rejected r -> Rejected r)
  | Blocked_on b -> Blocked_on b
  | Rejected { diagnostic = wkr_err; rollback = _ } ->
    let synthesized_wkr_pos = Obj.magic wkr_err in
    let sup_diagnostic_feedback = node.delegation_lens.bwd sup_pos synthesized_wkr_pos in
    (match Agent.step node.supervisor sup_diagnostic_feedback with
     | Progress { new_pos = recovered_pos; delta_tokens = sup_tok; trace = _ } ->
       Progress {
         new_pos = (recovered_pos, Obj.magic ());
         delta_tokens = sup_tok;
         trace = Printf.sprintf "Supervisor absorbed worker error: %s" wkr_err;
       }
     | Blocked_on b -> Blocked_on b
     | Rejected r -> Rejected r)

let aggregate_tokens node =
  add_tokens (Agent.total_tokens node.supervisor) (Agent.total_tokens node.worker)
