(* open MenhirSdk.Cmly_format *)

let ranged ?(start = 0) max =
  let rec go i : _ Seq.t = fun () -> if i < max then Cons (i, go (i + 1)) else Nil in
  go start

let tbl out body =
  Format.fprintf out "{@;<0 4>@[<hov>%t@]@,}" @@ fun out ->
  let first = ref true in
  body (fun x ->
      Format.fprintf out
        ("%t" ^^ x ^^ ",")
        (fun out -> if !first then first := false else Format.pp_print_space out ()))

(** Convert a string to a valid Lua identifier. *)
let lua_ident str =
  let len = String.length str in
  let b = Buffer.create len in
  for i = 0 to len - 1 do
    let c = str.[i] in
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' then
      Buffer.add_char b c
  done;
  Buffer.contents b

(** Convert an OCaml array index to a Lua one. Yes, it just adds one. *)
let lua_idx n = n + 1

let main ~cmly ~errors ?header () =
  (* Extract our grammar. *)
  let errors = In_channel.(with_open_text errors input_all) |> String.trim in
  let module G = MenhirSdk.Cmly_read.Read (struct
    let filename = cmly
  end) in
  (* And build a parser. *)
  let valid_terminals_start = 1 (* Exclude error. *) in
  let valid_terminals_end = G.Terminal.count - 1 (* Exclude the '#' terminal. *) in
  let valid_terminals_n = valid_terminals_end - valid_terminals_start in
  let eof =
    G.Terminal.fold (fun t eof -> if G.Terminal.name t = "EOF" then Some t else eof) None
    |> Option.get
  in

  let n_idx x = G.Nonterminal.to_int x + valid_terminals_n in
  let t_idx x =
    (* Map the "#" token to EOF. It's janky, but whatever :). *)
    let x =
      match G.Terminal.kind x with
      | `PSEUDO -> eof
      | _ -> x
    in
    G.Terminal.to_int x - valid_terminals_start
  in

  (* Exclude the error terminal. *)

  (* Print out our list of tokens. *)
  let tokens =
    Format.asprintf "%a" tbl @@ fun item ->
    ranged ~start:valid_terminals_start valid_terminals_end
    |> Seq.map (fun x -> G.Terminal.of_int x |> G.Terminal.name)
    |> Seq.iter (item "%S");
    item "%S" "COMMENT";
    item "%S" "ERROR"
  in

  let start_production =
    G.Production.fold
      (fun p max -> if G.Production.kind p = `START then G.Production.to_int p else max)
      0
    |> lua_idx |> Int.neg |> string_of_int
  in
  let productions =
    Format.asprintf "%a" tbl @@ fun item ->
    G.Production.iter (fun prod ->
        item "{ %d, %d }"
          (G.Production.lhs prod |> n_idx |> lua_idx)
          (Array.length (G.Production.rhs prod)))
  in

  let transitions =
    Format.asprintf "%a" tbl @@ fun item ->
    G.Lr1.iter (fun lr1 ->
        let transitions = Array.make (valid_terminals_n + G.Nonterminal.count) "f" in
        let set i x =
          if transitions.(i) <> "f" then failwith ("Duplicate transition " ^ string_of_int i);
          transitions.(i) <- x
        in
        List.iter
          (fun (symbol, dest) ->
            match symbol with
            | G.N non_term -> set (n_idx non_term) (G.Lr1.to_int dest |> lua_idx |> string_of_int)
            | G.T terminal -> set (t_idx terminal) (G.Lr1.to_int dest |> lua_idx |> string_of_int))
          (G.Lr1.transitions lr1);
        List.iter
          (fun (symbol, prod) ->
            let prod =
              match prod with
              | [ x ] -> x
              | _ -> failwith "Invalid production"
            in
            set (t_idx symbol) (G.Production.to_int prod |> lua_idx |> Int.neg |> string_of_int))
          (G.Lr1.reductions lr1);

        (* We assume the happy path (i.e. the transition exists) and skip trailing "f"s. *)
        let _, last_idx =
          Array.fold_left
            (fun (i, last) x -> (i + 1, if x = "f" then last else i))
            (0, 0) transitions
        in
        let b = Buffer.create 16 in
        for i = 0 to last_idx do
          if i > 0 then Buffer.add_string b ", ";
          Buffer.add_string b transitions.(i)
        done;
        Buffer.contents b |> item "{ %s }")
  in
  let starts =
    Format.asprintf "@[<v 4>%t@]" @@ fun out ->
    List.iteri
      (fun i (non_term, _, lr1) ->
        if i > 0 then Format.fprintf out "@;";
        Format.fprintf out "%s = %d, --[[- The %s starting state. ]]"
          (G.Nonterminal.name non_term |> lua_ident)
          (G.Lr1.to_int lr1 |> lua_idx)
          (G.Nonterminal.name non_term |> lua_ident))
      G.Grammar.entry_points
  in

  (* And return the eventual parser. *)
  Option.iter
    (fun header ->
      In_channel.(with_open_text header input_all) |> print_string;
      print_newline ())
    header;
  Parser_template.v ~tokens ~productions ~start_production ~transitions ~errors ~starts
  |> print_string

let () =
  let term =
    let ( let+ ) x f = Cmdliner.Term.(const f $ x) in
    let ( and+ ) a b = Cmdliner.Term.(const (fun x y -> (x, y)) $ a $ b) in
    let open Cmdliner.Arg in
    let+ cmly =
      required
      & pos 0 (some file) None
      & info ~docv:"CMLY" ~doc:"The grammar's $(b,.cmly) file, as generated by Menhir." []
    and+ errors =
      required
      & pos 1 (some file) None
      & info ~docv:"ERRORS"
          ~doc:
            "The error handling code. This should be a Lua file, typically derived from a lrgrep \
             $(b,.mlyl) file."
          []
    and+ header =
      value
      & opt (some file) None
      & info ~docv:"HEADER" ~doc:"A header file to prepend to the generated text." [ "header" ]
    in
    main ~cmly ~errors ?header ()
  in

  let open Cmdliner.Cmd in
  v (info "lua_menhir" ~doc:"Convert a Menhir parser to a Lua module.") term |> eval |> exit
