--- A lookup table of valid Lua tokens
local tokens = (function() return {} end)() -- Make tokens opaque to illuaminate. Nasty!
for i, token in ipairs(_T.tokens()) do tokens[token] = i end
setmetatable(tokens, { __index = function(_, name) error("No such token " .. tostring(name), 2) end })

--- Read a integer with a given size from a string.
local function get_int(str, offset, size)
    if size == 1 then
        return str:byte(offset + 1)
    elseif size == 2 then
        local hi, lo = str:byte(offset + 1, offset + 2)
        return hi * 256 + lo
    elseif size == 3 then
        local b1, b2, b3 = str:byte(offset + 1, offset + 3)
        return b1 * 256 + b2 + b3 * 65536 -- Don't ask.
    else
        error("Unsupported size", 2)
    end
end

--[[ Error handling:

Errors are extracted from the current parse state in a two-stage process:
 - Run a DFA over the current state of the LR1 stack. For each accepting state,
   register a parse error.
 - Once all possible errors are found, pick the best of these and report it to
   the user.

This process is performed by a tiny register-based virtual machine. The bytecode
for this machine is stored in `error_message_program`, and the accompanying
transition table in `error_message_table`.

It would be more efficient to use tables here (`string.byte` is 2-3x slower than
a table lookup) or even define the DFA as a Lua program, however this approach
is much more space efficient - shaving off several kilobytes.

See https://github.com/let-def/lrgrep/ (namely ./support/lrgrep_runtime.ml) for
more information.
]]

_T.errors()

local function handle_error(context, stack, stack_n, token, token_start, token_end)
    -- Run our error handling virtual machine.
    local pc, top, registers, messages = error_message_program_start, stack_n, {}, {}
    while true do
        local instruction = error_message_program:byte(pc + 1)
        if instruction == 1 then -- Store(reg:8b)
            local reg = error_message_program:byte(pc + 2)
            registers[reg + 1] = top
            pc = pc + 2
        elseif instruction == 2 then -- Move(r1:8b, r2:8b)
            local r1 = error_message_program:byte(pc + 2)
            local r2 = error_message_program:byte(pc + 3)
            registers[r2 + 1] = registers[r1 + 1]
            pc = pc + 3
        elseif instruction == 3 then -- Clear(reg:8b)
            local reg = error_message_program:byte(pc + 2)
            registers[reg + 1] = nil
            pc = pc + 2
        elseif instruction == 4 then -- Yield (Pop one item from the stack and jump)
            -- TODO: Add support for interpret_last. Do we need this?
            if top > 1 then top = top - 3 end
            pc = get_int(error_message_program, pc + 1, 3)
        elseif instruction == 5 then -- Accept
            local clause = get_int(error_message_program, pc + 1, 2)
            local priority, arity = error_message_program:byte(pc + 4, pc + 5)
            local accept = { clause = clause + 1, priority = priority }
            for i = 1, arity do accept[i] = registers[error_message_program:byte(pc + 5 + i) + 1] end
            messages[#messages + 1] = accept

            pc = pc + 5 + arity
        elseif instruction == 6 then -- Match(index:24b)
            local index = get_int(error_message_program, pc + 1, 3)
            local lr1 = stack[top] - 1

            local ksize, vsize = error_message_table:byte(1, 2)
            local offset = 2 + (index + lr1) * (ksize + vsize)
            if offset + 4 + ksize <= #error_message_table and
                get_int(error_message_table, offset, ksize) == lr1 + 1 then
                pc = get_int(error_message_table, offset + ksize, vsize)
            else
                pc = pc + 4
            end
        elseif instruction == 7 then -- Halt
            break
        elseif instruction == 8 then -- Priority(clause:16b, p1:8b, p2:8b)
            local clause = get_int(error_message_program, pc + 1, 2)
            local p1, p2 = error_message_program:byte(pc + 3, pc + 5)

            for i = 1, #messages do
                local msg = messages[i]
                if msg.clause == clause and msg.priority == p1 then msg.priority = p2 end
            end
            pc = pc + 5
        else
            error("Illegal instruction while handling errors " .. tostring(instruction))
        end
    end

    -- Sort the list to ensure earlier patterns are used first.
    table.sort(messages, function(a, b)
        if a.clause == b.clause then
            return a.priority < b.priority
        else
            return a.clause < b.clause
        end
    end)

    -- Then loop until we find an error message which actually works!
    for i = 1, #messages do
        local action = messages[i]
        local message = error_message[action.clause](context, stack, stack_n, action, token, token_start, token_end)
        if message then
            context.report(message)
            return false
        end
    end

    context.report(errors.unexpected_token, token, token_start, token_end)
    return false
end

--- The list of productions in our grammar. Each is a tuple of `terminal * production size`.
local productions = _T.productions()

local f = false

--[[- The state machine used for our grammar.

Most LR(1) parsers will encode the transition table in a compact binary format,
optimised for space and fast lookups. However, without access to built-in
bitwise operations, this is harder to justify in Lua. Instead, the transition
table is a 2D lookup table of `action = transitions[state][value]`, where
`action` can be one of the following:

 - `action = false`: This transition is undefined, and thus a parse error. We
   use this (rather than nil) to ensure our tables are dense, and thus stored as
   arrays rather than maps.

 - `action > 0`: Shift this terminal or non-terminal onto the stack, then
   transition to `state = action`.

 - `action < 0`: Apply production `productions[-action]`. This production is a
   tuple composed of the next state and the number of values to pop from the
   stack.
]]
local transitions = _T.transitions()

--- Run the parser across a sequence of tokens.
--
-- @tparam table context The current parser context.
-- @tparam function get_next A stateful function which returns the next token.
-- @treturn boolean Whether the parse succeeded or not.
local function parse(context, get_next, start)
    local stack, stack_n = { start or 1, 1, 1 }, 1
    local reduce_stack = {}

    while true do
        local token, token_start, token_end = get_next()
        local state = stack[stack_n]
        local action = transitions[state][token]

        if not action then -- Error
            return handle_error(context, stack, stack_n, token, token_start, token_end)
        elseif action >= 0 then -- Shift
            stack_n = stack_n + 3
            stack[stack_n], stack[stack_n + 1], stack[stack_n + 2] = action, token_start, token_end
        elseif action >= _T.start_production() then -- Accept
            return true
        else -- Reduce
            -- Reduction is quite complex to get right, as the error code expects the parser
            -- to be shifting rather than reducing. Menhir achieves this by making the parser
            -- stack be immutable, but that's hard to do efficiently in Lua: instead we track
            -- what symbols we've pushed/popped, and only perform this change when we're ready
            -- to shift again.

            local popped, pushed = 0, 0
            while true do
                -- Look at the current item to reduce
                local reduce = productions[-action]
                local terminal, to_pop = reduce[1], reduce[2]

                -- Find the state at the start of this production. If to_pop == 0
                -- then use the current state.
                local lookback = state
                if to_pop > 0 then
                    pushed = pushed - to_pop
                    if pushed <= 0 then
                        -- If to_pop >= pushed, then clear the reduction stack
                        -- and consult the normal stack.
                        popped = popped - pushed
                        pushed = 0
                        lookback = stack[stack_n - popped * 3]
                    else
                        -- Otherwise consult the stack of temporary reductions.
                        lookback = reduce_stack[pushed]
                    end
                end

                state = transitions[lookback][terminal]
                if not state or state <= 0 then error("reduce must shift!") end

                -- And fetch the next action
                action = transitions[state][token]

                if not action then -- Error
                    return handle_error(context, stack, stack_n, token, token_start, token_end)
                elseif action >= 0 then -- Shift
                    break
                elseif action >= _T.start_production() then -- Accept
                    return true
                else
                    pushed = pushed + 1
                    reduce_stack[pushed] = state
                end
            end

            if popped == 1 and pushed == 0 then
                -- Handle the easy case: Popped one item and replaced it with another
                stack[stack_n] = state
            else
                -- Otherwise pop and push.
                -- FIXME: The positions of everything here are entirely wrong.
                local end_pos = stack[stack_n + 2]
                stack_n = stack_n - popped * 3
                local start_pos = stack[stack_n + 1]

                for i = 1, pushed do
                    stack_n = stack_n + 3
                    stack[stack_n], stack[stack_n + 1], stack[stack_n + 2] = reduce_stack[i], end_pos, end_pos
                end

                stack_n = stack_n + 3
                stack[stack_n], stack[stack_n + 1], stack[stack_n + 2] = state, start_pos, end_pos
            end

            -- Shift the token onto the stack
            stack_n = stack_n + 3
            stack[stack_n], stack[stack_n + 1], stack[stack_n + 2] = action, token_start, token_end
        end
    end
end

return {
    tokens = tokens,
    parse = parse,
    _T.starts()
}
