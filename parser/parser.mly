%token BREAK DO ELSE ELSEIF END FALSE FOR FUNCTION GOTO IF IN LOCAL NIL
%token REPEAT RETURN THEN TRUE UNTIL WHILE EOF

%token COLON ":"
%token DOUBLE_COLON "::"
%token COMMA ","
%token DOT "."
%token DOTS "..."
%token EQUALS "="
%token SEMICOLON ";"

%token OPAREN "(" CPAREN ")"
%token OBRACE "{" CBRACE "}"
%token OSQUARE "[" CSQUARE "]"

%token ADD "+" SUB "-" MUL "*" DIV "/" POW "^" MOD "%"
%token CONCAT ".."
%token EQ "==" NE "~=" LT "<" LE "<=" GT ">" GE ">="
%token LEN "#"

%token AND OR
%token NOT

%token IDENT
%token STRING
%token NUMBER

%left OR
%left AND
%left "<" ">" "<=" ">=" "~=" "=="
%right ".."
%left "+" "-"
%left "*" "/" "%"
%right NOT
%right "^"

%start <unit> program
%start <unit> repl_exprs

%on_error_reduce
  name
  var

  expr_pow

  stmts

%%

let program := stmts ; EOF ; {()}

let repl_exprs :=
  | sep_list1(",", expr) ; EOF ; {()}

let ident :=
  | IDENT ; {()}
  | GOTO  ; {()}

let var := ident ; {()}

let arg :=
  | var ; {()}
  | "..." ; {()}

let args :=
  | "(" ; sep_list0(",", arg) ; ")"
  ; {()}

let name :=
  | var
  ; {()}
  | simple_expr ; "." ; ident
  ; {()}
  | simple_expr ; "[" ; expr ; "]"
  ; {()}

let simple_expr :=
  | name ; {()}
  | "(" ; expr ; ")"
  ; {()}
  | call ; {()}

let call :=
  | simple_expr ; call_args
  ; {()}
  | simple_expr ; ":" ; ident ; call_args
  ; {()}

let call_args :=
  | "(" ; sep_list0(",", expr) ; ")"
  ; {()}
  | STRING ; {()}
  | table  ; {()}

(* Expressions *)
let atom :=
  | simple_expr
  | table   ; <>
  | NIL     ; <>
  | TRUE    ; <>
  | FALSE   ; <>
  | "..."   ; <>
  | NUMBER  ; <>
  | STRING  ; <>
  | FUNCTION ; args ; stmts ; END
  ; {()}

let expr :=
  | expr_pow

  | expr ; AND ; expr ; {()}
  | expr ; OR  ; expr ; {()}


  | expr ; "+" ; expr ; {()}
  | expr ; "-" ; expr ; {()}
  | expr ; "*" ; expr ; {()}
  | expr ; "/" ; expr ; {()}
  | expr ; "%" ; expr ; {()}

  | expr ; ".." ; expr ; {()}

  | expr ; "==" ; expr ; {()}
  | expr ; "~=" ; expr ; {()}
  | expr ; "<"  ; expr ; {()}
  | expr ; "<=" ; expr ; {()}
  | expr ; ">"  ; expr ; {()}
  | expr ; ">=" ; expr ; {()}

let expr_pow :=
  | atom
  | expr_pow ; "^" ; expr_pow
  ; {()}

  | "-" ; expr_pow
  ; {()} %prec NOT
  | "#" ; expr_pow ; {()} %prec NOT
  | NOT ; expr_pow ; {()} %prec NOT

(* Tables *)
let table :=
  | "{" ; table_body ; "}"
  ; {()}

let table_sep := ";" | ","

let table_body :=
  | {()}
  | table_entry ; {()}
  | table_entry ; table_sep ; table_body ; {()}

let table_entry :=
  | expr ; {()}
  | ident ; "=" ; expr ;{()}
  | "[" ; expr ;  "]" ; "=" ; expr
  ; {()}

(* Statements *)

let stmts :=
  | rlist(stmt) ; last_stat ; {()}

let last_stat :=
  | {()}
  | RETURN ; sep_list0(",", expr) ; ioption(";") ; {()}

let stmt :=
  | DO ; stmts ; END
  ; {()}

  | sep_list1(",", name) ; "=" ; sep_list1(",", expr)
  ; {()}

  | WHILE ; expr ; DO ; stmts ; END
  ; {()}

  | REPEAT ; stmts ; UNTIL ; expr
  ; {()}

  | if_clause(IF) ; rlist(if_clause(ELSEIF)) ; END
  ; {()}

  | if_clause(IF) ; rlist(if_clause(ELSEIF)) ; ELSE ; stmts ; END
  ; {()}

  | FOR ; var ; "=" ; expr ; ","; expr ; DO ; stmts ; END
  ; {()}

  | FOR ; var ; "=" ; expr ; ","; expr ; "," ; expr ; DO ; stmts ; END
  ; {()}

  | FOR ; sep_list1(",", var) ; IN ; sep_list1(",", expr)
  ; DO ; stmts ; END
  ; {()}

  | LOCAL ; sep_list1(",", var) ; {()}
  | LOCAL ; sep_list1(",", var) ; "=" ; sep_list1(",", expr) ; {()}

  | LOCAL ; FUNCTION ; var ; args
  ; stmts ; END
  ; {()}

  | FUNCTION ; function_name; args
  ; stmts ; END
  ; {()}

  | call ; {()}

  | ";" ; {()}
  | BREAK ; {()}
  | GOTO ; ident ; {()}
  | "::" ; ident ; "::" ; {()}

let function_name :=
  | var ; {()}
  | function_name ; "." ; IDENT ; {()}
  | function_name ; ":" ; IDENT  ; {()}

let if_clause(t) ==
  | t ; expr ; THEN ; stmts ;
  {()}

let sep_list1(separator, X) :=
  | X ; {()}
  | sep_list1(separator, X); separator; X ; {()}

let sep_list0(separator, X) :=
  | {()}
  | sep_list1(separator, X) ; {()}

let rlist(x) :=
  | {()}
  | rlist(x) ; x ; {()}
