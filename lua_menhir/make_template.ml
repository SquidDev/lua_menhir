(* Match [_T.some_ident()]. *)
let subst =
  let open Re in
  seq
    [ str "_T.";
      group (seq [ alt [ lower; upper; char '_' ]; rep (alt [ lower; upper; digit; char '_' ]) ]);
      str "()"
    ]
  |> compile

let () =
  let contents = In_channel.input_all stdin in

  let len = String.length contents in
  let buffer = Buffer.create len in
  let rec iter seen pos =
    if pos < len then (
      match Re.exec ~pos subst contents with
      | exception Not_found ->
          String.sub contents pos (len - pos) |> Printf.bprintf buffer "%S";
          seen
      | group ->
          let start, fin = Re.Group.offset group 0 in
          let name = Re.Group.get group 1 in
          Printf.bprintf buffer "%S ^ %s ^ " (String.sub contents pos (start - pos)) name;
          iter (name :: seen) fin)
    else seen
  in
  let seen = iter [] 0 in

  print_string "let v ";
  List.sort_uniq String.compare seen |> List.iter (Printf.printf "~%s ");
  print_string "= ";
  Buffer.contents buffer |> print_string
