(* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. *)

open Batteries
open Printf

let parse xs =
  let rec parse' = function
    | [] -> []
    | x :: xs ->
      begin match float_of_string x with
      | x' -> `Float x' :: parse' xs
      | exception Failure _ -> `String x :: parse' xs
      end
  in parse' xs

let compare xs ys =
  let rec compare' = function
    | x :: xs, y :: ys -> 
      let result =
        match x, y with
        | `String x', `String y' -> String.compare x' y'
        | `Float n, `Float m ->
          if n > m then 1
          else if n < m then -1
          else 0
        | `Float _, `String _ -> -1
        | `String _, `Float _ -> 1
      in
      if result <> 0 then result
      else compare' (xs, ys)
    | _ :: _, [] -> 1
    | [], _ :: _ -> -1
    | [], [] -> 0
  in
  compare' (xs, ys)

let index haystack needle =
  let rec loop i =
    if i >= String.length haystack then raise Not_found
    else if List.mem haystack.[i] needle then i
    else loop (succ i)
  in 
  loop 0

let renumber parts i =
  let rec renumber' = function
    | [] -> raise Not_found
    | `Float _ :: rest -> `Float i :: rest
    | `String _ as head :: rest -> head :: renumber' rest
  in
  try renumber' parts 
  with Not_found -> `Float i :: parts

let unparse separator parts =
  let out = Buffer.create 17 in
  let separate = function
    | [] -> ()
    | _ -> Buffer.add_string out separator
  in
  let rec unparse' = function
    | [] -> ()
    | `Float f :: rest ->
      Buffer.add_string out (string_of_int @@ int_of_float @@ f) ;
      separate rest ;
      unparse' rest
    | `String s :: rest ->
      Buffer.add_string out s ;
      separate rest ;
      unparse' rest
  in
  unparse' parts ;
  Buffer.contents out

let (@.) f g x =
  f (g x)

let do_rename_in renames target =
  let inp = Pervasives.open_in target in
  let out = Buffer.create 17 in
  input_lines inp
  |> Enum.map (fun s ->
    match List.assoc s renames with
    | s' -> s'
    | exception Not_found -> s
  )
  |> Enum.iter (fun s ->
    Buffer.add_string out s ;
    (* What about Windows? *)
    Buffer.add_char out '\n'
  ) ;
  Pervasives.close_in inp ;
  output_file ~filename:target ~text:(Buffer.contents out)

let () =
  let prefix = ref "patch" in
  let separator = ref "-" in
  let quiet = ref false in
  let rename_in = ref [] in
  let speclist =
    [("-p", Arg.Set_string prefix,
      " The prefix for the files to renumber. Defaults to 'patch'.");
     ("-s", Arg.Set_string separator,
      " The part separator.");
     ("-q", Arg.Set quiet,
      " Be quiet.");
     ("-f", Arg.String (fun s -> rename_in := s :: !rename_in),
      " A file to rename references to renamed files in.")]
  in
  let usage_msg = "A file renumbering tool." in
  let anon_fun _ =
    Arg.usage speclist usage_msg ;
    exit 1
  in

  Arg.parse speclist anon_fun usage_msg ;

  List.iter (fun target ->
    if not (Sys.file_exists target) then
      fprintf stderr "Can't rename references in '%s' because it doesn't seem to exist." target
  ) !rename_in ;

  let renames = 
    Sys.readdir "."
    |> Array.to_list 
    |> List.filter (fun s -> try String.find s !prefix = 0 with Not_found -> false)
    |> List.map (fun name -> 
      let unprefixed = String.tail name (String.length !prefix) in
      let parsed = parse @@ String.nsplit unprefixed ~by:!separator in
      (name, parsed)
    )
    |> List.sort (fun (_, xs) (_, ys) -> compare xs ys) 
    |> List.mapi (fun i (file, parts) ->
      let parts' = renumber parts (float_of_int @@ i + 1) in
      let file' = unparse !separator parts' in
      (file, !prefix ^ file')
    )
    |> List.filter (fun (file, file') -> file <> file')
  in

  List.iter (fun (file, file') ->
    if file <> file' && Sys.file_exists file' then begin
      fprintf stderr "Can't rename '%s' to '%s' because a different file with that name already exists."
        file file' ;
      exit 1
    end
  ) renames ;

  List.iter (fun (file, file') ->
    if not !quiet then
      printf "'%s' -> '%s'\n" file file' ;
    Sys.rename file file'
  ) renames ;

  List.iter (fun target ->
    if not !quiet then
      printf "Renaming references in '%s'...\n" target ;
    do_rename_in renames target
  ) !rename_in ;

  if not !quiet then
    printf "Done!\n"
