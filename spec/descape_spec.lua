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

   it("handles comples keypad escapes", function ()
      local keypad_escapes = {
         keypad_up = {
            ["\27[1;2A"] = { ctrl = false, shift = true,  alt = false },
            ["\27[1;3A"] = { ctrl = false, shift = false, alt = true  },
            ["\27[1;4A"] = { ctrl = false, shift = true,  alt = true  },
            ["\27[1;5A"] = { ctrl = true,  shift = false, alt = false },
            ["\27[1;6A"] = { ctrl = true,  shift = true,  alt = false },
            ["\27[1;7A"] = { ctrl = true,  shift = false, alt = true  },
         },
         keypad_down = {
            ["\27[1;2B"] = { ctrl = false, shift = true,  alt = false },
            ["\27[1;3B"] = { ctrl = false, shift = false, alt = true  },
            ["\27[1;4B"] = { ctrl = false, shift = true,  alt = true  },
            ["\27[1;5B"] = { ctrl = true,  shift = false, alt = false },
            ["\27[1;6B"] = { ctrl = true,  shift = true,  alt = false },
            ["\27[1;7B"] = { ctrl = true,  shift = false, alt = true  },
         },
         keypad_right = {
            ["\27[1;2C"] = { ctrl = false, shift = true,  alt = false },
            ["\27[1;3C"] = { ctrl = false, shift = false, alt = true  },
            ["\27[1;4C"] = { ctrl = false, shift = true,  alt = true  },
            ["\27[1;5C"] = { ctrl = true,  shift = false, alt = false },
            ["\27[1;6C"] = { ctrl = true,  shift = true,  alt = false },
            ["\27[1;7C"] = { ctrl = true,  shift = false, alt = true  },
         },
         keypad_left = {
            ["\27[1;2D"] = { ctrl = false, shift = true,  alt = false },
            ["\27[1;3D"] = { ctrl = false, shift = false, alt = true  },
            ["\27[1;4D"] = { ctrl = false, shift = true,  alt = true  },
            ["\27[1;5D"] = { ctrl = true,  shift = false, alt = false },
            ["\27[1;6D"] = { ctrl = true,  shift = true,  alt = false },
            ["\27[1;7D"] = { ctrl = true,  shift = false, alt = true  },
         },
      }
      for handler, variants in pairs(keypad_escapes) do
         for escape_sequence, modifiers in pairs(variants) do
            local delegate = {}
            stub(delegate, handler)
            decode(iter_bytes(escape_sequence), delegate)
            assert.stub(delegate[handler]).called_with(delegate, modifiers)
         end
      end
   end)

   it("handles DSR reports", function ()
      local delegate = {}
      stub(delegate, "device_status_reported")
      decode(iter_bytes("\27[0n"), delegate)
      assert.stub(delegate.device_status_reported).called_with(delegate, 0)
      -- Try omitting the optional parameter.
      decode(iter_bytes("\27[n"), delegate)
      assert.stub(delegate.device_status_reported).called_with(delegate, 0)
   end)

   it("handles DSR cursor reports", function ()
      local delegate = {}
      stub(delegate, "cursor_position_reported")
      decode(iter_bytes("\27[12;5R"), delegate)
      assert.stub(delegate.cursor_position_reported)
         .called_with(delegate, 12, 5)
      -- Try omitting the optional parameters.
      decode(iter_bytes("\27[42R"), delegate)
      assert.stub(delegate.cursor_position_reported)
         .called_with(delegate, 42, 1)
      decode(iter_bytes("\27[R"), delegate)
      assert.stub(delegate.cursor_position_reported)
         .called_with(delegate, 1, 1)
   end)
end)
