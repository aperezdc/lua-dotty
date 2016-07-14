#! /usr/bin/env lua
--
-- asciicodes_spec.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local S = string.format

describe("dotty.asciicodes", function ()
   local A = require "dotty.asciicodes"

   it("string indexing returns codes", function ()
      for name, _ in pairs(A) do
         if type(name) == "string" then
            assert.message(S("index %q does not produce a number", name))
               .is_number(A[name])
         end
      end
   end)

   it("numeric indexing returns strings", function ()
      for i = 0, #A do
         assert.message(S("index 0x%02X does not produce a string", i))
            .is_string(A[i])
      end
   end)

   it("is consistent", function ()
      for i = 0, #A do
         local name = A[i]
         assert.message(S("A[%q] is 0x%02X, expected 0x%02X", name, A[name], i))
            .is_equal(i, A[name])
      end
   end)

end)
