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

   local function prefixed_keys(prefix, keys)
      return coroutine.wrap(function ()
         for name, code in pairs(keys) do
            coroutine.yield(name, prefix .. code)
         end
      end)
   end

   local modifiers = {
      [";2"] = { ctrl = false, shift = true,  alt = false },
      [";3"] = { ctrl = false, shift = false, alt = true  },
      [";4"] = { ctrl = false, shift = true,  alt = true  },
      [";5"] = { ctrl = true,  shift = false, alt = false },
      [";6"] = { ctrl = true,  shift = true,  alt = false },
      [";7"] = { ctrl = true,  shift = false, alt = true  },
   }
   local function prefixed_keys_with_modifiers(prefix, keys)
      return coroutine.wrap(function ()
         for name, code in pairs(keys) do
            for mod_code, mods in pairs(modifiers) do
               coroutine.yield(name, prefix .. mod_code .. code, mods)
            end
         end
      end)
   end

   local arrow_keys = {
      key_up = "A", key_down = "B", key_right = "C", key_left = "D"
   }

   local function test_delegate_keys(generator)
      for handler, escape_sequence, modifiers in generator do
         local delegate = {}
         stub(delegate, handler)
         decode(iter_bytes(escape_sequence), delegate)
         local msg = string.format("escape %q for %s",
                                   escape_sequence, handler)
         assert.stub(delegate[handler]).message(msg).called_with(delegate,
            modifiers or { ctrl = false, alt = false, shift = false })
      end
   end

   it("handles simple arrow key escapes", function ()
      test_delegate_keys(prefixed_keys("\27O", arrow_keys))
   end)

   it("handles VT52 arrow key escapes", function ()
      test_delegate_keys(prefixed_keys("\27", arrow_keys))
   end)

   it("handles complex keypad escapes", function ()
      test_delegate_keys(prefixed_keys_with_modifiers("\27[1", arrow_keys))
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

   it("handles What Are You? reports", function ()
      local delegate = {}
      stub(delegate, "device_attributes_reported")
      for _, num in ipairs { 0, 1, 2, 3, 4, 5, 6, 7 } do
         decode(iter_bytes(string.format("\27[?1;%dc", num)), delegate)
         assert.stub(delegate.device_attributes_reported)
            .called_with(delegate, num)
      end
   end)
end)
