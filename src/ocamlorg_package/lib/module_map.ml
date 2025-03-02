open Import

type kind =
  | Module
  | Page
  | Leaf_page
  | Module_type
  | Parameter of int
  | Class
  | Class_type
  | File

let prefix_of_kind = function
  | Module_type -> "module-type-"
  | Parameter i -> "argument-" ^ Int.to_string i ^ "-"
  | Class -> "class-"
  | Class_type -> "class-type-"
  | _ -> ""

module Module = struct
  type t = {
    name : string;
    kind : kind;
    mutable submodules : t String.Map.t;
    parent : t option;
  }

  let name t = t.name
  let kind t = t.kind
  let submodules t = t.submodules
  let parent t = t.parent

  let path v =
    let rec aux acc v =
      let item = prefix_of_kind v.kind ^ v.name in
      match v.parent with
      | None -> item :: acc
      | Some parent -> aux (item :: acc) parent
    in
    aux [ "index.html" ] v |> String.concat "/"
end

type library = {
  name : string;
  dependencies : string list;
  modules : Module.t String.Map.t;
}

type t = { libraries : library String.Map.t }

open Yojson.Safe.Util

let kind_of_yojson v =
  match to_string v with
  | "page" -> Page
  | "module" -> Module
  | "leaf-page" -> Leaf_page
  | "module-type" -> Module_type
  | "class" -> Class
  | "class-type" -> Class_type
  | "file" -> File
  | s when String.starts_with ~prefix:"argument-" s ->
      let i = List.hd (List.tl (String.split_on_char '-' s)) in
      Parameter (int_of_string i)
  | _ -> raise (Type_error ("Variant not supported", v))

let rec module_of_yojson ?parent v : Module.t =
  let name = member "name" v |> to_string in
  let kind = member "kind" v |> kind_of_yojson in
  let module' = { Module.name; kind; parent; submodules = String.Map.empty } in
  let submodules =
    member "submodules" v |> to_list |> List.to_seq
    |> Seq.map (fun v ->
           let submodule = module_of_yojson ~parent:module' v in
           (submodule.name, submodule))
    |> String.Map.of_seq
  in
  module'.submodules <- submodules;
  module'

let library_of_yojson v =
  let name = member "name" v |> to_string in
  let modules =
    member "modules" v |> to_list |> List.to_seq
    |> Seq.map (fun v ->
           let module' = module_of_yojson v in
           (module'.name, module'))
    |> String.Map.of_seq
  in
  let dependencies =
    match member "dependencies" v with
    | `Null -> []
    | `List l -> List.rev_map to_string l
    | v -> raise (Type_error ("Failed to parse dependencies field", v))
  in
  { name; modules; dependencies }

let of_yojson json =
  member "libraries" json |> to_list |> List.to_seq
  |> Seq.map (fun v ->
         let lib = library_of_yojson v in
         (lib.name, lib))
  |> String.Map.of_seq
  |> fun libraries -> { libraries }
