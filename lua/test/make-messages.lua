#!/usr/bin/env lua
--[[
Converts Menhir's error messages file (passed on stdin) into a list of test
cases which can be passed to ./check-markdown.lua.

This is used to generate ./parser_messages_spec.md: see the dune file in the
parent directory.
]]

local token_names = {
    ADD = "+",
    AND = "and",
    BREAK = "break",
    CBRACE = "}",
    COLON = ":",
    COMMA = ",",
    CONCAT = "..",
    CPAREN = ")",
    CSQUARE = "]",
    DIV = "/",
    DO = "do",
    DOT = ".",
    DOTS = "...",
    DOUBLE_COLON = "::",
    ELSE = "else",
    ELSEIF = "elseif",
    END = "end",
    EQ = "==",
    EQUALS = "=",
    FALSE = "false",
    FOR = "for",
    FUNCTION = "function",
    GE = ">=",
    -- Nasty hack. We can't easily distinguish the IDENT and GOTO in our ident production, so treat the two as the same.
    GOTO = "xyz",
    GT = ">",
    IDENT = "xyz",
    IF = "if",
    IN = "in",
    LE = "<=",
    LEN = "#",
    LOCAL = "local",
    LT = "<",
    MOD = "%",
    MUL = "*",
    NE = "~=",
    NIL = "nil",
    NOT = "not",
    NUMBER = "123",
    OBRACE = "{",
    OPAREN = "(",
    OR = "or",
    OSQUARE = "[",
    POW = "^",
    REPEAT = "repeat",
    RETURN = "return",
    SEMICOLON = ";",
    STRING = "'abc'",
    SUB = "-",
    THEN = "then",
    TRUE = "true",
    UNTIL = "until",
    WHILE = "while",
    EOF = "--[[eof]]"
}

io.write([[
An exhaustive list of all error states in the parser, and the error messages we
generate for each one. This is _not_ a complete collection of all possible
errors, but is a useful guide for where we might be providing terrible messages.]])

local inputs = {}
for line in io.lines() do
    local start, tokens = line:match("^([a-z_]+): (.+)$")
    if start then inputs[#inputs + 1] = { start = start, tokens = tokens } end
end

table.sort(inputs, function(x, y)
    if x.tokens == y.tokens then
        return x.start < y.start
    else
        return x.tokens < y.tokens
    end
 end)

for _, input in ipairs(inputs) do
    io.write("\n\n")
    io.write("```lua")
    if input.start ~= "program" then io.write(" {", input.start, "}") end
    io.write("\n")

    local lua = input.tokens:gsub("([A-Z_]+)", token_names)
    print(lua)

    -- Print PUC Lua's error
    do
        local ok, err = load(lua, "=in")
        local msg = ok and "Error: Lua accepted this code!" or err
        -- If this error occurs inside repl_exprs, we don't know if it's a statement
        -- or expression. We guess by checking if the reported error mentions the last
        -- token in the input code.
        if input.start == "repl_exprs" and msg:match("near '(.*)'") ~= lua:match("(%S+)$") then
            local ok, err = load("return " .. lua, "=in")
            if not ok then msg = err end
        end

        msg = msg:gsub("^in:", "Line ")

        io.write("-- ", msg, " (", input.start, ")\n")
    end

    print("```")
end
