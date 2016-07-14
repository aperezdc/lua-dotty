-- #! /usr/bin/env lua
-- --
-- descape_spec.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local function iter_bytes(s)
   return coroutine.wrap(function ()
      for i = 1, #s do
         coroutine.yield(string.byte(s, i))
      end
   end)
end

describe("dotty.descape.decode", function ()
   local decode = require "dotty.descape" .decode

   it("handles simple keypad escapes", function ()
      local simple_keypad_escapes = {
         keypad_up    = "\27OA",
         keypad_down  = "\27OB",
         keypad_right = "\27OC",
         keypad_left  = "\27OD",
      }
      for handler, escape_sequence in pairs(simple_keypad_escapes) do
         local delegate = {}
         stub(delegate, handler)
         decode(iter_bytes(escape_sequence), delegate)
         assert.stub(delegate[handler]).called_with(delegate,
            { ctrl = false, alt = false, shift = false })
      end
   end)
end)
