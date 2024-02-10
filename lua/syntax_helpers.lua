local expect = require "cc.expect"

local function make_context(input)
    expect(1, input, "string")

    local lines = { 1 }
    local function line(pos) lines[#lines + 1] = pos end

    local function get_pos(pos)
        expect(1, pos, "number")

        for i = #lines, 1, -1 do
            local start = lines[i]
            if pos >= start then return i, pos - start + 1 end
        end

        error("Position is <= 0", 2)
    end

    local function report(message, ...)
        expect(3, message, "function", "table")
        if type(message) == "function" then message = message(...) end

        for _, msg in ipairs(message) do
            if type(msg) == "table" and msg.tag == "annotate" then
                local line, col = get_pos(msg.start_pos)
                local end_line, end_col = get_pos(msg.end_pos)

                local next_line = lines[line + 1]
                local contents = input:sub(lines[line], next_line and next_line - 1 or #input):gsub("[\r\n].*", "")
                print("   |")
                print(("%2d | %s"):format(line, contents))

                local indicator = line == end_line and ("^"):rep(end_col - col + 1) or "^..."
                if #msg.msg > 0 then
                    print(("   | %s%s %s"):format((" "):rep(col - 1), indicator, msg.msg))
                else
                    print(("   | %s%s"):format((" "):rep(col - 1), indicator))
                end
            else
                print(tostring(msg))
            end
        end
    end

    return { line = line, get_pos = get_pos, report = report }
end

return { make_context = make_context }
