(** [Dsh_plugins.Sandbox] - Isolated Execution Environment & Virtual Filesystem *)

type file_entry = {
  path : string;
  content : string;
  modified_at : float;
}

type t

(** Create a new in-memory virtual sandbox *)
val create : ?root_dir:string -> unit -> t

(** Write a virtual file in the sandbox *)
val write_file : t -> path:string -> content:string -> (unit, string) result

(** Read a virtual file from the sandbox *)
val read_file : t -> path:string -> (string, string) result

(** Check if file exists *)
val exists : t -> path:string -> bool

(** Remove file from sandbox *)
val remove_file : t -> path:string -> (unit, string) result

(** List all files in sandbox *)
val list_files : t -> string list

(** Tokenize shell command string supporting single/double quotes and escapes *)
val tokenize_command : string -> (string list, string) result

(** Execute an in-memory virtual command or script *)
val eval_command : t -> string -> (int * string * string, string) result

(** Snapshot virtual state for time-travel *)
val snapshot : t -> (string * string) list

(** Restore virtual state from snapshot *)
val restore : t -> (string * string) list -> unit
