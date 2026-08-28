(* gbnf.ml - ADT-to-GBNF Compiler Implementation *)

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

let type_to_gbnf_rule = function
  | G_String -> "\"\\\"\" [^\"\\\\]* \"\\\"\""
  | G_Int -> "[0-9]+"
  | G_Float -> "[0-9]+ (\".\" [0-9]+)?"
  | G_Bool -> "(\"true\" | \"false\")"
  | G_Custom custom -> custom
  | G_List inner ->
    "\"[\" (" ^ (match inner with
      | G_String -> "\"\\\"\" [^\"\\\\]* \"\\\"\""
      | G_Int -> "[0-9]+"
      | _ -> "[^]]*") ^ " (\",\" " ^ (match inner with
      | G_String -> "\"\\\"\" [^\"\\\\]* \"\\\"\""
      | G_Int -> "[0-9]+"
      | _ -> "[^]]*") ^ ")*)? \"]\""

let compile_enum_to_gbnf ~rule_name tags =
  let quoted_tags = List.map (fun t -> Printf.sprintf "\"\\\"%s\\\"\"" t) tags in
  let choices = String.concat " | " quoted_tags in
  Printf.sprintf "%s ::= (%s)" rule_name choices

let compile_record_to_gbnf (rec_def : record_def) =
  let field_rules = List.map (fun (name, t) ->
    let rule_str = type_to_gbnf_rule t in
    Printf.sprintf "\"\\\"%s\\\": \" %s" name rule_str
  ) rec_def.fields in
  let body = String.concat " \", \" " field_rules in
  Printf.sprintf "root ::= \"{\" %s \"}\"" body

let compile_adt_to_gbnf (adt : adt_def) =
  let ctor_rules = List.map (fun c ->
    if c.args = [] then
      Printf.sprintf "\"{\\\"tag\\\": \\\"%s\\\"}\"" c.name
    else
      let arg_rules = List.map (fun (arg_name, t) ->
        Printf.sprintf "\"\\\"%s\\\": \" %s" arg_name (type_to_gbnf_rule t)
      ) c.args in
      let args_str = String.concat " \", \" " arg_rules in
      Printf.sprintf "\"{\\\"tag\\\": \\\"%s\\\", \" %s \"}\"" c.name args_str
  ) adt.constructors in
  let choices = String.concat " | " ctor_rules in
  Printf.sprintf "root ::= (%s)" choices

let matches_enum tags output =
  let trimmed = String.trim output in
  let unquoted =
    if String.starts_with ~prefix:"\"" trimmed && String.ends_with ~suffix:"\"" trimmed then
      String.sub trimmed 1 (String.length trimmed - 2)
    else trimmed
  in
  List.mem unquoted tags
