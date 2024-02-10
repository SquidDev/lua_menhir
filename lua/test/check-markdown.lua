#!/usr/bin/env lua
--[[
This consumes a markdown file with Lua code blocks, runs them through our Lua
parser, and reports an error for each one. This error is displayed in a code
block below the original Lua one.

The "reformatted" file (with the resulting error messages) is printed to stdout,
and then can be diffed against the input file. See the dune file in the parent
directory for examples of how this is used.
]]

-- Add some stubs for CC-specific code.
colours = { lightGrey = -1 }

local lex_one = require "cc.internal.syntax.lexer".lex_one
local parser = require "cc.internal.syntax.parser"
local make_context = require "syntax_helpers".make_context
local parse, tokens, last_token = parser.parse, parser.tokens, parser.tokens.COMMENT

local function run_parser(input, print_tokens, start)
    local error_sentinel = {}

    local function get_name(token)
        for name, tok in pairs(tokens) do if tok == token then return name end end
        return "?[" .. tostring(token) .. "]"
    end

    local context = make_context(input)

    local pos = 1
    local ok, err = xpcall(function()
        return parse(context, function()
            while true do
                local token, start, finish, content = lex_one(context, input, pos)
                if not token then return tokens.EOF, #input + 1, #input + 1 end

                if print_tokens then
                    local start_line, start_col = context.get_pos(start)
                    local end_line, end_col = context.get_pos(finish)
                    local text = input:sub(start, finish)
                    print(("%d:%d-%d:%d %s %s"):format(
                        start_line, start_col, end_line, end_col,
                        get_name(token), content or text:gsub("\n", "<NL>")
                    ))
                end

                pos = finish + 1

                if token < last_token then
                    return token, start, finish
                elseif token == tokens.ERROR then
                    error(error_sentinel)
                end
            end
        end, start)
    end, debug.traceback)

    if not ok and err ~= error_sentinel then
        print(tostring(err))
    end
end

local filename, print_tokens = nil, false

for _, arg in ipairs(arg) do
    if arg == "--help" or arg == "-h" then
        io.stderr:write("syntax [-T] INPUT\n")
        os.exit(1)
    elseif arg == "-T" then
        print_tokens = true
    else
        if filename then
            io.stderr:write("Filename argument already given (", filename, ")\n")
            os.exit(1)
        end

        filename = arg
    end
end

if not filename then
    io.stderr:write("No filename given\n")
    os.exit(1)
end

local input = assert(io.open(filename, "r"))
local contents = input:read("*a")
input:close()

local pos = 1

while true do
    local _, lua_end, kind, lua = contents:find("```lua *([^\n]*)\n(.-)\n```\n?", pos)
    if not lua_end then
        io.write(contents:sub(pos))
        break
    end

    local start = nil
    if #kind > 0 then
        start = parser[kind:match("^{([a-z_]+)}$")]
        if not start then
            io.stderr:write("Cannot extract start symbol ", kind, "\n")
            os.exit(1)
        end
    end

    print(contents:sub(pos, lua_end))

    local _, txt_end = contents:find("^\n*```txt\n.-\n```\n", lua_end + 1)
    print("```txt")
    run_parser(lua, print_tokens, start)
    print("```")

    pos = (txt_end or lua_end) + 1
end
