(* open_game.ml - Open Game Categorical Cybernetics *)

type ('state, 'strat, 'ctx, 'obs, 'co_obs, 'co_ctx, 'utility) game = {
  play : 'strat -> 'state -> 'ctx -> 'obs;
  coplay : 'strat -> 'state -> 'co_obs -> ('co_ctx * 'utility);
  best_response : 'state -> 'ctx -> ('obs -> 'co_obs -> 'utility) -> 'strat;
}

let make_game ~play ~coplay ~best_response = {
  play;
  coplay;
  best_response;
}

let compose
    (g1 : ('s1, 'strat1, 'ctx, 'mid_obs, 'mid_co_obs, 'co_ctx, 'u1) game)
    (g2 : ('s2, 'strat2, 'mid_obs, 'final_obs, 'final_co_obs, 'mid_co_obs, 'u2) game) :
    ('s1 * 's2, 'strat1 * 'strat2, 'ctx, 'final_obs, 'final_co_obs, 'co_ctx, 'u1 * 'u2) game =
  {
    play = (fun (strat1, strat2) (s1, s2) ctx ->
      let mid_obs = g1.play strat1 s1 ctx in
      g2.play strat2 s2 mid_obs);
    coplay = (fun (strat1, strat2) (s1, s2) final_co_obs ->
      let mid_co_obs, u2 = g2.coplay strat2 s2 final_co_obs in
      let co_ctx, u1 = g1.coplay strat1 s1 mid_co_obs in
      (co_ctx, (u1, u2)));
    best_response = (fun (s1, s2) ctx continuation ->
      let strat1 = g1.best_response s1 ctx (fun mid_obs mid_co_obs ->
        let _, u1 = g1.coplay (Obj.magic ()) s1 mid_co_obs in
        u1) in
      let mid_obs = g1.play strat1 s1 ctx in
      let strat2 = g2.best_response s2 mid_obs (fun final_obs final_co_obs ->
        let _, u2 = g2.coplay (Obj.magic ()) s2 final_co_obs in
        u2) in
      (strat1, strat2));
  }

let tensor
    (g1 : ('s1, 'strat1, 'ctx1, 'obs1, 'co_obs1, 'co_ctx1, 'u1) game)
    (g2 : ('s2, 'strat2, 'ctx2, 'obs2, 'co_obs2, 'co_ctx2, 'u2) game) :
    ('s1 * 's2, 'strat1 * 'strat2, 'ctx1 * 'ctx2, 'obs1 * 'obs2, 'co_obs1 * 'co_obs2, 'co_ctx1 * 'co_ctx2, 'u1 * 'u2) game =
  {
    play = (fun (strat1, strat2) (s1, s2) (ctx1, ctx2) ->
      (g1.play strat1 s1 ctx1, g2.play strat2 s2 ctx2));
    coplay = (fun (strat1, strat2) (s1, s2) (co_obs1, co_obs2) ->
      let co_ctx1, u1 = g1.coplay strat1 s1 co_obs1 in
      let co_ctx2, u2 = g2.coplay strat2 s2 co_obs2 in
      ((co_ctx1, co_ctx2), (u1, u2)));
    best_response = (fun (s1, s2) (ctx1, ctx2) continuation ->
      let strat1 = g1.best_response s1 ctx1 (fun o1 co1 ->
        let _, (u1, _) = continuation (o1, Obj.magic ()) (co1, Obj.magic ()) in
        u1) in
      let strat2 = g2.best_response s2 ctx2 (fun o2 co2 ->
        let _, (_, u2) = continuation (Obj.magic (), o2) (Obj.magic (), co2) in
        u2) in
      (strat1, strat2));
  }

let is_nash_equilibrium ~game ~state ~strat ~ctx ~co_obs ~equal_strat =
  let optimal_strat = game.best_response state ctx (fun _obs incoming_co_obs ->
    let _, u = game.coplay strat state incoming_co_obs in
    u) in
  equal_strat strat optimal_strat
