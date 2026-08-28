(** [Dsh_poly.Open_game] - Categorical Cybernetics & Open Games
    Formalizes Open Games (Hedges, Spivak, Capucci) for multi-agent game-theoretic equilibrium composition. *)

type ('state, 'strat, 'ctx, 'obs, 'co_obs, 'co_ctx, 'utility) game = {
  play : 'strat -> 'state -> 'ctx -> 'obs;
  coplay : 'strat -> 'state -> 'co_obs -> ('co_ctx * 'utility);
  best_response : 'state -> 'ctx -> ('obs -> 'co_obs -> 'utility) -> 'strat;
}

(** Construct a basic reactive game agent *)
val make_game :
  play:('strat -> 'state -> 'ctx -> 'obs) ->
  coplay:('strat -> 'state -> 'co_obs -> ('co_ctx * 'utility)) ->
  best_response:('state -> 'ctx -> ('obs -> 'co_obs -> 'utility) -> 'strat) ->
  ('state, 'strat, 'ctx, 'obs, 'co_obs, 'co_ctx, 'utility) game

(** Sequential composition of open games (G1 followed by G2) *)
val compose :
  ('s1, 'strat1, 'ctx, 'mid_obs, 'mid_co_obs, 'co_ctx, 'u1) game ->
  ('s2, 'strat2, 'mid_obs, 'final_obs, 'final_co_obs, 'mid_co_obs, 'u2) game ->
  ('s1 * 's2, 'strat1 * 'strat2, 'ctx, 'final_obs, 'final_co_obs, 'co_ctx, 'u1 * 'u2) game

(** Parallel tensor composition of open games (G1 (x) G2) *)
val tensor :
  ('s1, 'strat1, 'ctx1, 'obs1, 'co_obs1, 'co_ctx1, 'u1) game ->
  ('s2, 'strat2, 'ctx2, 'obs2, 'co_obs2, 'co_ctx2, 'u2) game ->
  ('s1 * 's2, 'strat1 * 'strat2, 'ctx1 * 'ctx2, 'obs1 * 'obs2, 'co_obs1 * 'co_obs2, 'co_ctx1 * 'co_ctx2, 'u1 * 'u2) game

(** Evaluate Nash equilibrium condition for a game given an environment context *)
val is_nash_equilibrium :
  game:('state, 'strat, 'ctx, 'obs, 'co_obs, 'co_ctx, float) game ->
  state:'state ->
  strat:'strat ->
  ctx:'ctx ->
  co_obs:'co_obs ->
  equal_strat:('strat -> 'strat -> bool) ->
  bool
