(** [Dsh_plugins.Model_router] - Multi-Tier Model Router & Token Economics
    Implements heterogeneous model tiering (Frontier, Flash, Verifier) and prompt caching. *)

open Dsh_core.Types

type model_tier =
  | Frontier      (** Heavy architectural planning (e.g., Claude 3.5 Sonnet, Gemini Pro) *)
  | Flash         (** Rapid generation & AST edits (e.g., Gemini Flash, DeepSeek-V3) *)
  | Local_verifier (** $0.00 token deterministic native proof/type checker *)

type model_config = {
  tier : model_tier;
  model_name : string;
  cost_per_million_prompt : float;
  cost_per_million_completion : float;
  context_limit : int;
}

val default_config : model_tier -> model_config

type generation_request = {
  tier : model_tier;
  system_prompt : string;
  messages : message list;
  max_tokens : int;
  temperature : float;
  grammar : string option; (** Optional GBNF grammar constraint for structured decoding *)
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

(** In-process Llama.cpp provider generator with KV-cache fork support *)
val create_llama_provider :
  config:llama_config ->
  (generation_request -> (generation_response, string) result)

(** Fork KV cache sequence for algebraic effect backtracking (llama_kv_cache_seq_cp) *)
val fork_kv_cache :
  seq_src:kv_sequence_id ->
  seq_dst:kv_sequence_id ->
  (unit, string) result

type router

val create_router : unit -> router

(** Register custom mock or real API provider *)
val set_provider :
  router ->
  (generation_request -> (generation_response, string) result) ->
  unit

(** Generate completion with token cost accounting and cache lookup *)
val generate : router -> generation_request -> (generation_response, string) result

(** Extract typed AST code blocks from model response (e.g. ```ocaml ... ```) *)
val extract_code_block : lang:string -> string -> string option
