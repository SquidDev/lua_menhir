let do_parse (type a) (checkpoint : Lexing.position -> a Parser.MenhirInterpreter.checkpoint)
    (lexbuf : Lexing.lexbuf) =
  let initial = lexbuf.lex_start_p in
  let module I = Parser.MenhirInterpreter in
  let module PE = Lrgrep_runtime.Interpreter (Parse_errors.Table_error_message) (I) in
  let rec loop : _ I.env -> _ -> _ I.checkpoint -> _ =
   fun env tok -> function
    | I.InputNeeded env' as cp ->
        let tok' = Lexer.token lexbuf in
        let tok' = (tok', lexbuf.Lexing.lex_start_p, lexbuf.Lexing.lex_curr_p) in
        loop env' tok' (I.offer cp tok')
    | (I.Shifting (_, _, _) | I.AboutToReduce (_, _)) as cp -> loop env tok (I.resume cp)
    | I.Accepted x -> x
    | I.Rejected -> assert false
    | I.HandlingError _ -> (
      match PE.run env with
      | [] ->
          prerr_endline "Syntax error (no handler for it)";
          exit 1
      | matches ->
          if false then
            Printf.eprintf "Matches: %s\n"
              (String.concat ", " (List.map (fun (x, _) -> string_of_int x) matches));
          let rec loop = function
            | [] ->
                prerr_endline "Syntax error (partial handler did not handle the case)";
                exit 1
            | m :: ms -> (
              match Parse_errors.execute_error_message m initial tok with
              | None -> loop ms
              | Some err -> prerr_endline err; exit 1)
          in
          loop matches)
  in
  match checkpoint lexbuf.lex_curr_p with
  | I.InputNeeded env as cp ->
      let tok' = Lexer.token lexbuf in
      let tok' = (tok', lexbuf.Lexing.lex_start_p, lexbuf.Lexing.lex_curr_p) in
      loop env tok' (I.offer cp tok')
  | _ -> assert false

let () =
  let input = Lexing.from_channel stdin in
  do_parse Parser.Incremental.program input
