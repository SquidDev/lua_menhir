#!/usr/bin/env lua
colours = {}
local lex_one = require "cc.internal.syntax.lexer".lex_one
local parser = require "cc.internal.syntax.parser"
local parse, tokens, last_token = parser.parse, parser.tokens, parser.tokens.COMMENT

local function run_parser(input)
    local error_sentinal = {}

    local lines = { 1 }
    local function line(pos) lines[#lines + 1] = pos end

    local function get_pos(pos)
        for i = #lines, 1, -1 do
            local start = lines[i]
            if pos >= start then return i, pos - start + 1 end
        end

        error("Position is <= 0", 2)
    end

    local function get_name(token)
        for name, tok in pairs(tokens) do if tok == token then return name end end
        return "?[" .. tostring(token) .. "]"
    end

    local function report(parts)
        for _, msg in ipairs(parts) do
            if type(msg) == "table" and msg.tag == "annotate" then
                local line, col = get_pos(msg.start_pos)
                local end_line, end_col = get_pos(msg.end_pos)

                local next_line = lines[line + 1]
                local contents = input:sub(lines[line], next_line and next_line - 1 or #input):gsub("[\r\n].*", "")
                print("   |")
                print(("%2d | %s"):format(line, contents))

                local indicator = line == end_line and ("^"):rep(end_col - col + 1) or "^..."
                print(("   | %s%s %s"):format((" "):rep(col - 1), indicator, msg.msg))
            else
                print(msg)
            end
        end
    end

    local lexer = { report = report, line = line, get_pos = get_pos }

    local parsers = {
        coroutine.create(parse),
        coroutine.create(require "cc.internal.syntax.parser2".parse),
    }

    for i = 1, #parsers do
        local ok, err = coroutine.resume(parsers[i], lexer, coroutine.yield)
        if not ok then
            print(debug.traceback(parsers[i], err))
            return
        end
    end

    local i, pos = 1, 1
    while true do
        local token, start, finish
        while true do
            token, start, finish = lex_one(lexer, input, pos)
            if not token then
                token, start, finish = tokens.EOF, #input, #input
                break
            end

            pos = finish + 1

            if token < last_token then
                break
            elseif token == tokens.ERROR then
                return
            end
        end

        print(("#"):rep(60) .. " Token " .. i)

        local fail = false
        for i = 1, #parsers do
            print("Parser " .. i)
            local ok, err = coroutine.resume(parsers[i], token, start, finish)
            if not ok then
                print(debug.traceback(parsers[i], err))
                fail = true
            end

            if coroutine.status(parsers[i]) == "dead" then fail = true end
        end

        if fail then return end

        i = i + 1
    end
end

if arg[1] == "-" then
    run_parser(io.read("*a"))
    return
end

while true do
    io.write("> ")
    io.flush()

    local line = io.read("*l")
    if not line then break end

    run_parser(line)
end
