#! /usr/bin/env lua
--
-- unidecode_spec.lua
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

describe("dotty.unidecode()", function ()
   local unidecode = require "dotty.unidecode"

   it("returns 7-bit ASCII unmodified", function ()
      local reader = spy.new(function () end)
      for i = 0, 127 do
         assert.is_equal(string.char(i), unidecode(reader, i))
      end
      -- We are passing the first byte, reader function won't be called.
      assert.spy(reader).called(0)
   end)

   it("accepts a couroutine reader", function ()
      for i = 0, 127 do
         local reader = coroutine.wrap(function ()
            coroutine.yield(i)
         end)
         assert.is_equal(string.char(i), unidecode(reader))
      end
   end)

   it("errors on out-of-bounds bytes", function ()
      local oob_bytes =
         { 192, 193, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255 }
      for _, byte in ipairs(oob_bytes) do
         assert.message(string.format("byte %d (0x%02X)", byte, byte))
            .error_matches(function () unidecode(nil, byte) end,
               "^Invalid UTF8")
      end
   end)
end)
