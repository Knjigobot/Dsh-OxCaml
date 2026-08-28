(** [Dsh_eval.Edgebench] - EdgeBench Log-Sigmoid Scaling Law Evaluator
    Quantifies agent performance P(t) = 1 / (1 + (t_mid / t)^beta) over interaction time t. *)

type scaling_params = {
  t_mid : float; (** Characteristic interaction time to reach 50% success *)
  beta : float;  (** Transition sharpness / phase change parameter *)
}

type data_point = {
  interaction_time : float; (** Time or step count t *)
  performance_score : float; (** Measured accuracy / completion rate in [0, 1] *)
}

(** Theoretical log-sigmoid performance prediction *)
val predict_performance : params:scaling_params -> t:float -> float

(** Compute coefficient of determination (R^2) between model and empirical data *)
val compute_r2 : params:scaling_params -> data:data_point list -> float

(** Fit optimal scaling parameters (t_mid, beta) from empirical runs *)
val fit_scaling_law : data:data_point list -> (scaling_params * float, string) result

(** Compare Poly-hierarchical convergence speed vs flat chat loop *)
type comparison_result = {
  flat_scaling : scaling_params;
  poly_scaling : scaling_params;
  speedup_factor_at_90pct : float;
  token_reduction_pct : float;
}

val evaluate_poly_advantage :
  flat_runs:data_point list ->
  poly_runs:data_point list ->
  (comparison_result, string) result
