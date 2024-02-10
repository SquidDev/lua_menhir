-- SPDX-FileCopyrightText: 2023 The CC: Tweaked Developers
--
-- SPDX-License-Identifier: MPL-2.0

--[[- A parser for Lua programs and expressions.

> [!DANGER]
> This is an internal module and SHOULD NOT be used in your own code. It may
> be removed or changed at any time.

Most of the code in this module is automatically generated from the Lua grammar,
hence being mostly unreadable!

@local
]]

-- Lazily load our map of errors
local errors = setmetatable({}, {
    __index = function(self, key)
        setmetatable(self, nil)
        for k, v in pairs(require "cc.internal.syntax.errors") do self[k] = v end

        return self[key]
    end,
})

-- Everything below this line is auto-generated. DO NOT EDIT.
