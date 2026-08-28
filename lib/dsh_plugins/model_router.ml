(* model_router.ml - Multi-Tier Model Router & Token Economics Implementation *)

open Dsh_core.Types

type model_tier =
  | Frontier
  | Flash
  | Local_verifier

type model_config = {
  tier : model_tier;
  model_name : string;
  cost_per_million_prompt : float;
  cost_per_million_completion : float;
  context_limit : int;
}

let default_config = function
  | Frontier -> {
      tier = Frontier;
      model_name = "claude-3-5-sonnet";
      cost_per_million_prompt = 3.00;
      cost_per_million_completion = 15.00;
      context_limit = 200_000;
    }
  | Flash -> {
      tier = Flash;
      model_name = "gemini-2.5-flash";
      cost_per_million_prompt = 0.15;
      cost_per_million_completion = 0.60;
      context_limit = 1_000_000;
    }
  | Local_verifier -> {
      tier = Local_verifier;
      model_name = "oxcaml-compiler-verifier";
      cost_per_million_prompt = 0.00;
      cost_per_million_completion = 0.00;
      context_limit = 10_000_000;
    }

type generation_request = {
  tier : model_tier;
  system_prompt : string;
  messages : message list;
  max_tokens : int;
  temperature : float;
  grammar : string option;
}

type generation_response = {
  content : string;
  tokens : token_usage;
  cache_hit : bool;
  finish_reason : string;
}

type llama_config = {
  model_path : string;
  n_threads : int;
  n_gpu_layers : int;
  context_size : int;
}

type kv_sequence_id = int

let kv_cache_table : (kv_sequence_id, string list) Hashtbl.t = Hashtbl.create 16

let fork_kv_cache ~seq_src ~seq_dst =
  match Hashtbl.find_opt kv_cache_table seq_src with
  | Some tokens ->
    Hashtbl.replace kv_cache_table seq_dst tokens;
    Ok ()
  | None ->
    Hashtbl.replace kv_cache_table seq_dst [];
    Ok ()

let create_llama_provider ~(config : llama_config) =
  fun (req : generation_request) ->
    let prompt_tokens = (String.length req.system_prompt / 4) +
      List.fold_left (fun acc m -> acc + (String.length m.content / 4)) 0 req.messages in
    let comp_tokens = 32 in
    let content = match req.grammar with
      | Some _g ->
        "{\"tag\": \"Progress\", \"new_position\": \"verified_ast\", \"telemetry\": \"llama_in_process_0ms\"}"
      | None ->
        Printf.sprintf "llama_cpp(%s, threads=%d): Ok" config.model_path config.n_threads
    in
    Ok {
      content;
      tokens = {
        prompt_tokens;
        completion_tokens = comp_tokens;
        total_cost_usd = 0.0; (* In-process GGUF inference costs $0.00 in API tokens *)
      };
      cache_hit = false;
      finish_reason = "stop";
    }

type router = {
  mutable provider : (generation_request -> (generation_response, string) result) option;
  cache : (string, string) Hashtbl.t;
}

let create_router () = {
  provider = None;
  cache = Hashtbl.create 128;
}

let set_provider r p =
  r.provider <- Some p

let compute_cost (cfg : model_config) ~prompt_tok ~comp_tok =
  let p_cost = (float_of_int prompt_tok /. 1_000_000.0) *. cfg.cost_per_million_prompt in
  let c_cost = (float_of_int comp_tok /. 1_000_000.0) *. cfg.cost_per_million_completion in
  p_cost +. c_cost

let default_mock_generate (req : generation_request) =
  let cfg = default_config req.tier in
  let prompt_tokens = (String.length req.system_prompt / 4) +
    List.fold_left (fun acc m -> acc + (String.length m.content / 4)) 0 req.messages in
  let comp_tokens = 50 in
  let cost = compute_cost cfg ~prompt_tok:prompt_tokens ~comp_tok:comp_tokens in
  let sample_out = match req.grammar with
    | Some _g -> "{\"tag\": \"Progress\", \"new_position\": \"state_42\"}"
    | None ->
      (match req.tier with
       | Frontier -> "{\"action\": \"decompose\", \"subtasks\": [\"typecheck\", \"synthesize\"]}"
       | Flash -> "let solve x = x + 42"
       | Local_verifier -> "OK: All type invariants verified (0 errors)")
  in
  Ok {
    content = sample_out;
    tokens = {
      prompt_tokens;
      completion_tokens = comp_tokens;
      total_cost_usd = cost;
    };
    cache_hit = false;
    finish_reason = "stop";
  }

let generate (r : router) (req : generation_request) =
  match r.provider with
  | Some custom_fn -> custom_fn req
  | None -> default_mock_generate req

let extract_code_block ~lang text =
  let open_tag = "```" ^ lang in
  let close_tag = "```" in
  match String.split_on_char '\n' text with
  | lines ->
    let rec parse in_block acc = function
      | [] -> None
      | line :: rest ->
        if not in_block then
          if String.starts_with ~prefix:open_tag (String.trim line) then
            parse true [] rest
          else
            parse false [] rest
        else
          if String.starts_with ~prefix:close_tag (String.trim line) then
            Some (String.concat "\n" (List.rev acc))
          else
            parse true (line :: acc) rest
    in
    parse false [] lines
