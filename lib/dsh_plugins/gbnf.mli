(** [Dsh_plugins.Gbnf] - ADT-to-GBNF (Grammar-Based Context-Free Grammar) Compiler
    Compiles OxCaml Algebraic Data Types (variants, records, schemas) into GBNF grammar rules
    for constrained LLM decoding in local backward leaf lenses (f#). *)

type gbnf_type =
  | G_String
  | G_Int
  | G_Float
  | G_Bool
  | G_Custom of string
  | G_List of gbnf_type

type constructor_def = {
  name : string;
  args : (string * gbnf_type) list;
}

type adt_def = {
  type_name : string;
  constructors : constructor_def list;
}

type record_def = {
  record_name : string;
  fields : (string * gbnf_type) list;
}

(** Compiles an OCaml variant type definition into a GBNF grammar string *)
val compile_adt_to_gbnf : adt_def -> string

(** Compiles an OCaml record type definition into a JSON-compliant GBNF grammar string *)
val compile_record_to_gbnf : record_def -> string

(** Compiles a simple enum of variant tag strings into a GBNF choice rule *)
val compile_enum_to_gbnf : rule_name:string -> string list -> string

(** Validates whether a generated output matches a simple GBNF choice rule *)
val matches_enum : string list -> string -> bool
