{
  [@@@coverage exclude_file]
  let buffer_with len char =
    let b = Buffer.create len in
    Buffer.add_char b char;
    b
}

let white = [' ' '\t']


let digit = ['0'-'9']
let hex = ['0'-'9' 'a'-'f' 'A'-'F']
let number = digit | ['E' 'e'] ['+' '-']? | '.'

let ident_head = ['a'-'z' 'A'-'Z' '_']
let ident_tail = ident_head | '_' | digit

rule token = parse
| white+ as x
| '\n'
| '\r' '\n'
| "--[" ('='* as x) '['
(* We split line comments into two parts. Otherwise "--[^\n]*" would match "--[[foo]]". *)
| "--"       { token lexbuf }

| "and"      { Parser.AND }
| "break"    { Parser.BREAK    }
| "do"       { Parser.DO       }
| "else"     { Parser.ELSE     }
| "elseif"   { Parser.ELSEIF   }
| "end"      { Parser.END      }
| "false"    { Parser.FALSE    }
| "for"      { Parser.FOR      }
| "function" { Parser.FUNCTION }
| "goto"     { Parser.GOTO     }
| "if"       { Parser.IF       }
| "in"       { Parser.IN       }
| "local"    { Parser.LOCAL    }
| "nil"      { Parser.NIL      }
| "not"      { Parser.NOT      }
| "or"       { Parser.OR       }
| "repeat"   { Parser.REPEAT   }
| "return"   { Parser.RETURN   }
| "then"     { Parser.THEN     }
| "true"     { Parser.TRUE     }
| "until"    { Parser.UNTIL    }
| "while"    { Parser.WHILE    }

| ":"        { Parser.COLON }
| "::"       { Parser.DOUBLE_COLON }
| ","        { Parser.COMMA }
| "."        { Parser.DOT }
| "..."      { Parser.DOTS }
| "="        { Parser.EQUALS }
| ";"        { Parser.SEMICOLON }

| '(' { Parser.OPAREN }  | ')' { Parser.CPAREN }
| '{' { Parser.OBRACE }  | '}' { Parser.CBRACE }
| '[' { Parser.OSQUARE } | ']' { Parser.CSQUARE }

| '+'  { Parser.ADD }
| '-'  { Parser.SUB }
| '*'  { Parser.MUL }
| '/'  { Parser.DIV }
| '^'  { Parser.POW }
| '%'  { Parser.MOD }
| ".." { Parser.CONCAT }
| "==" { Parser.EQ }
| "~=" { Parser.NE }
| "<"  { Parser.LT }
| "<=" { Parser.LE }
| ">"  { Parser.GT }
| ">=" { Parser.GE }
| '#'  { Parser.LEN }

(* Numbers *)
| "0x" hex+ as i         { Parser.NUMBER }
| digit+ as i            { Parser.NUMBER }
| digit number* as i     { Parser.NUMBER }
| '.' digit number* as i { Parser.NUMBER }

(* Identifiers *)
| ident_head ident_tail* as i { Parser.IDENT }

| '\"'          { string (buffer_with 17 '\"') (Buffer.create 17) '\"' lexbuf }
| '\''          { string (buffer_with 17 '\'') (Buffer.create 17) '\'' lexbuf }
| '[' ('='* as x) '[' { long_string (Buffer.create 16) (String.length x) (fun _ _ -> Parser.STRING) lexbuf }

| eof { Parser.EOF }

| _ { failwith "Unexpected character" }

and string contents value c = parse
| '\"'              { Buffer.add_char contents '\"';
                      if c = '\"' then Parser.STRING
                      else (Buffer.add_char value '\"'; string contents value c lexbuf) }
| '\''              { Buffer.add_char contents '\'';
                      if c = '\'' then Parser.STRING
                      else (Buffer.add_char value '\''; string contents value c lexbuf) }

| "\\a"             { Buffer.add_string contents "\\a";  Buffer.add_char value '\007'; string contents value c lexbuf }
| "\\b"             { Buffer.add_string contents "\\b";  Buffer.add_char value '\b';   string contents value c lexbuf }
| "\\f"             { Buffer.add_string contents "\\f";  Buffer.add_char value '\012'; string contents value c lexbuf }
| "\\n"             { Buffer.add_string contents "\\n";  Buffer.add_char value '\n';   string contents value c lexbuf }
| "\\r"             { Buffer.add_string contents "\\r";  Buffer.add_char value '\r';   string contents value c lexbuf }
| "\\v"             { Buffer.add_string contents "\\v";  Buffer.add_char value '\011'; string contents value c lexbuf }
| "\\t"             { Buffer.add_string contents "\\t";  Buffer.add_char value '\t';   string contents value c lexbuf }

| "\\x" ((hex hex?) as x)
                    { Buffer.add_string contents "\\x"; Buffer.add_string contents x;
                      Buffer.add_char value ("0x" ^ x |> int_of_string |> char_of_int);
                      string contents value c lexbuf }
| "\\" ((digit digit? digit?) as x)
                    { Buffer.add_char contents '\\'; Buffer.add_string contents x;
                      Buffer.add_char value (int_of_string x |> char_of_int);
                      string contents value c lexbuf }

| "\\" ([^ '\r' '\n'] as x)
                    { Buffer.add_char contents '\\'; Buffer.add_char contents x;
                      Buffer.add_char value x;
                      string contents value c lexbuf }

| [^'\\' '\"' '\'' '\n']+ as x
                    { Buffer.add_string contents x;
                      Buffer.add_string value x;
                      string contents value c lexbuf }

| eof { failwith "Unterminated string" }
| '\r' { failwith "Unterminated string" }
| '\n' { failwith "Unterminated string" }
| _ { failwith "Unexpected character" }

and long_string buf eqs term = parse
| [^']' '\r' '\n']+ as x { Buffer.add_string buf x;              long_string buf eqs term lexbuf }
| ']' '='* ']' as x      { if String.length x == eqs + 2
                           then term eqs (Buffer.contents buf)
                           else (Buffer.add_string buf x;        long_string buf eqs term lexbuf) }
| ']'                    { Buffer.add_char buf ']';              long_string buf eqs term lexbuf }
| '\n'                   { Buffer.add_char buf '\n'; long_string buf eqs term lexbuf }
| '\r' '\n'              { Buffer.add_string buf "\r\n"; long_string buf eqs term lexbuf }
| eof                    { failwith "Unterminated string" }

and line_comment = parse
| [^'\r' '\n']* as x     { failwith "Comment" }
