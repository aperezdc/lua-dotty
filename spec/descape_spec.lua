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
               modifiers or { ctrl = false, alt = false, shift = false },
               match.is_number())
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
   it("handles VT100 Home/End key escapes",
      test_delegate_keys(prefixed_keys("\27O", vtXXX_home_end_keys)))
   it("handles CSI Home/End key escapes",
      test_delegate_keys(keys_with_modifiers("\27[1%(modifier)s%(code)s",
                                             vtXXX_home_end_keys)))

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

   it("handles extended CSI-u keys", function ()
      local delegate = {}
      stub(delegate, "key")
      decode(iter_bytes("\27[8230u"), delegate)
      assert.stub(delegate.key).called_with(delegate,
         { ctrl = false, alt = false, shift = false },
         0x2026)  -- U+2026 / 8230 is '…'
      decode(iter_bytes("\27[8230;5u"), delegate)
      assert.stub(delegate.key).called_with(delegate,
         { ctrl = true, alt = false, shift = false },
         0x2026)
   end)

   it("accepts 0x9B as single-byte CSI", function ()
      local delegate = {}
      stub(delegate, "key_up")
      decode(iter_bytes(string.char(0x9B) .. "1;1A"), delegate)
      assert.stub(delegate.key_up).called_with(delegate,
         { ctrl = false, alt = false, shift = false }, 1)
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

   it("works without a delegate", function ()
      decode(iter_bytes("\27[31;1m"))
   end)

   it("handles unterminated escape sequences", function ()
      for _, sequence in ipairs {
         "\27",     -- Only ESC prefix
         "\27[",    -- Only CSI prefix
         "\27[1",   -- CSI prefix + parameter
         "\27[1;",  -- CSI prefix + parameter + separator
         "\27O",    -- VT100/ANSI with second byte missing
      } do
         assert.message(string.format("unterminated sequence %q", sequence))
            .not_has_error(function ()
               decode(iter_bytes(sequence))
            end)
      end
   end)

   it("restarts after a CAN/SUB character", function ()
      for _, sequence in ipairs {
         "\27\24\27[n",  -- CAN
         "\27\26\27[n",  -- SUB
         "\27[\24\27[n", -- CAN
         "\27[\26\27[n", -- SUB
      } do
         local delegate = {}
         stub(delegate, "device_status_reported")
         local msg = string.format("CAN/SUB sequence %q", sequence)
         assert.message(msg).not_has_error(function ()
            decode(iter_bytes(sequence), delegate)
         end)
         assert.stub(delegate.device_status_reported)
            .message(msg).called_with(delegate, match.is_number())
      end
   end)

   local function decode_loop(input, delegate)
      local nextbyte = iter_bytes(input)
      local result = ""
      while true do
         local c = decode(nextbyte, delegate)
         if c == nil then
            return result
         end
         result = result .. string.char(c)
      end
   end

   it("can be used to strip escape sequences", function ()
      for expected, inputs in pairs {
         [""] = {
            "", "\27", "\27[1A", "\27\27", "\27[1A\27", "\27\27[1A",
            "\27\24", "\27[\24", "\27[?\24", "\27[1;32\24",  -- CAN
            "\27\26", "\27[\26", "\27[?\26", "\27[1;32\26",  -- SUB
         },
         ["foobar"] = {
            "foobar\27",         -- Unterminated escape sequence
            "\27*foobar",        -- Discard one trailing character (prefix)
            "foo\27*bar",        -- Discard one trailing character (middle)
            "foobar\27*",        -- Discard one trailing character (suffix)
            "\27:*foobar",       -- Discard two trailing characters (prefix)
            "foo\27:*bar",       -- Discard two trailing characters (middle)
            "foobar\27:*",       -- Discard two trailing characters (suffix)
            "\27[1;31mfoobar",   -- Valid CSI sequence (prefix)
            "foo\27[1;31mbar",   -- Valid CSI sequence (middle)
            "foobar\27[1;31m",   -- Valid CSI sequence (suffix)
            "\27\24foobar",      -- CAN (prefix)
            "foo\27\24bar",      -- CAN (middle)
            "foobar\27\24",      -- CAN (middle)
            "\27\26foobar",      -- SUB (prefix)
            "foo\27\26bar",      -- SUB (middle)
            "foobar\27\26",      -- SUB (middle)
         },
      } do
         for _, input in ipairs(inputs) do
            local msg = string.format("input %q", input)
            assert.message(msg).equal(expected, decode_loop(input))
         end
      end
   end)

   it("catches errors in handlers", function ()
      local delegate = {}
      function delegate:key_up(modifiers, count)
         error("Evil666")
      end
      assert.error_matches(function ()
         decode(iter_bytes("\27OA"), delegate)
      end, "Evil666")
      stub(delegate, "error")
      assert.error_matches(function ()
         decode(iter_bytes("\27OA"), delegate)
      end, "Evil666")
      assert.stub(delegate.error).called_with(delegate, match.is_string())
   end)
end)
