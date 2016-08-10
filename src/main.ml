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
      Buffer.add_string out (string_of_int @@ int_of_float f) ;
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
  let infile_regex = ref "(^[^-+].*Part) [0-9]+" in
  let infile_subst = ref "$1 %d" in

  let speclist = [
    ("-p", Arg.Set_string prefix,
     " The prefix for the files to renumber. Defaults to 'patch'.");
    ("-s", Arg.Set_string separator,
     " The part separator.");
    ("-q", Arg.Set quiet,
     " Be quiet.");
    ("-f", Arg.String (fun s -> rename_in := s :: !rename_in),
     " A file to rename references to renamed files in.");
    ("-ir", Arg.Set_string infile_regex,
     " A regex whose matching strings in the renamed files will be substituted with -is.");
    ("-is", Arg.Set_string infile_subst,
     " A substition to apply. Refer to groups in -ir with $n, and new patch number with %d.");
  ]
  in
  let usage_msg = "A file renumbering tool." in
  let anon_fun _ =
    Arg.usage speclist usage_msg ;
    exit 1
  in

  Arg.parse speclist anon_fun usage_msg ;

  List.iter (fun target ->
    if not (Sys.file_exists target) then begin
      fprintf stderr "Can't rename references in '%s' because it doesn't seem to exist." target ;
      exit 1
    end
  ) !rename_in ;

  if (!infile_regex == "") <> (!infile_subst == "") then begin
    fprintf stderr "Must supply either both -ir and -ir or neither." ;
    exit 1
  end ;

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
      let parts' = renumber parts @@ float_of_int (i + 1) in
      let file' = unparse !separator parts' in
      (file, !prefix ^ file', i + 1)
    )
    |> List.filter (fun (file, file', _) -> file <> file')
  in

  if renames = [] then begin
    printf "No files scheduled for renaming with prefix '%s'.\n" !prefix ;
    exit 0
  end ;

  (* Check to make sure we can rename safely. *)
  List.iter (fun (file, file', _) ->
    if file <> file' && Sys.file_exists file' then begin
      fprintf stderr "Can't rename '%s' to '%s' because a different file with that name already exists."
        file file' ;
      exit 1
    end
  ) renames ;

  (* Apply substitution. *)
  if !infile_regex <> "" then begin
    let re = Pcre.regexp ~flags:[`MULTILINE] !infile_regex in
    List.iter (fun (file, _, i) ->
      let subst = Pcre.subst (String.nreplace ~str:!infile_subst ~sub:"%d" ~by:(string_of_int i)) in
      if not !quiet then
        printf "Substituting in '%s'...\n" file ;
      let inch = Pervasives.open_in file in
      let contents = input_all inch in
      Pervasives.close_in inch ;
      let contents' = Pcre.replace ~rex:re ~itempl:subst contents in
      output_file ~filename:file ~text:contents'
    ) renames
  end ;

  (* Rename files. *)
  List.iter (fun (file, file', _) ->
    if not !quiet then
      printf "'%s' -> '%s'\n" file file' ;
    Sys.rename file file'
  ) renames ;

  (* Rename references in -f file. *)
  List.iter (fun target ->
    if not !quiet then
      printf "Renaming references in '%s'...\n" target ;
    do_rename_in (List.map (fun (file, file', _) -> (file, file')) renames) target
  ) !rename_in ;

  if not !quiet then
    printf "Done!\n"
