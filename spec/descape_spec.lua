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

-- Rici Lake's interp() from http://lua-users.org/wiki/StringInterpolation
local function interpolate(s, tab)
  return (s:gsub('%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])',
            function(k, fmt) return tab[k] and ("%"..fmt):format(tab[k]) or
                '%('..k..')'..fmt end))
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
   local function keys_with_modifiers(format, keys)
      return coroutine.wrap(function ()
         for name, code in pairs(keys) do
            for mod_code, mods in pairs(modifiers) do
               local sequence = interpolate(format,
                  { code = code, modifier = mod_code })
               coroutine.yield(name, sequence, mods)
            end
         end
      end)
   end

   local function test_delegate_keys(generator)
      return function ()
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
   end

   local arrow_keys = {
      key_up = "A", key_down = "B", key_right = "C", key_left = "D",
   }
   it("handles VT52 arrow key escapes",
      test_delegate_keys(prefixed_keys("\27", arrow_keys)))
   it("handles VT100 arrow key escapes",
      test_delegate_keys(prefixed_keys("\27O", arrow_keys)))
   it("handles CSI arrow key escapes",
      test_delegate_keys(keys_with_modifiers("\27[1%(modifier)s%(code)s",
                                             arrow_keys)))

   local vtXXX_f1_f4_keys = {
      key_f1 = "P", key_f2 = "Q", key_f3 = "R", key_f4 = "S"
   }
   it("handles VT52 F1-F4 key escapes",
      test_delegate_keys(prefixed_keys("\27", vtXXX_f1_f4_keys)))
   it("handles VT100 F1-F4 key escapes",
      test_delegate_keys(prefixed_keys("\27O", vtXXX_f1_f4_keys)))

   local vtXXX_home_end_keys = {
      key_end = "F", key_home = "H"
   }
   it("handles VT52 Home/End key escapes",
      test_delegate_keys(prefixed_keys("\27", vtXXX_home_end_keys)))
   it("handles VT100 Home/End key escpes",
      test_delegate_keys(prefixed_keys("\27O", vtXXX_home_end_keys)))

   local csi_tilde_keys = {
      key_insert = "2", key_delete   = "3",
      key_pageup = "5", key_pagedown = "6",
      key_home   = "7", key_end      = "8",
      key_f1 = "11", key_f2  = "12", key_f3  = "13", key_f4  = "14",
      key_f5 = "15", key_f6  = "17", key_f7  = "18", key_f8  = "19",
      key_f9 = "20", key_f10 = "21", key_f11 = "23", key_f12 = "24",
   }
   it("handles CSI-~ function keys",
      test_delegate_keys(keys_with_modifiers("\27[%(code)s%(modifier)s~",
                                             csi_tilde_keys)))

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
