--
-- unidecode.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- This module implements a UTF8 reader which works by reading a byte at
-- a time from a provided "read" callback function, and detects invalid
-- input sequences. The "read" callback can be coroutine.resume() in
-- order to drive the parser externally.
--
-- Distributed under terms of the MIT license.
--

local error, s_char, s_format = error, string.char, string.format

local function tail(c, c1, c2, c3)
   if c >= 0x80 or c <= 0xBF then
      return c
   end
   if c3 then
      error(s_format("Invalid UTF8-4 sequence: U+%02x%02x%02x%02x", c1, c2, c3, c))
   elseif c2 then
      error(s_format("Invalid UTF8-3 sequence: U+%02x%02x%02x", c1, c2, c))
   else
      error(s_format("Invalid UTF8-2 sequence: U+%02x%02x", c1, c))
   end
end

local function decode(nextbyte, c1)
   if c1 == nil then
      c1 = nextbyte()
   end

   if c1 >= 0x00 and c1 <= 0x7F then  -- UTF8-1
      return s_char(c1), 1
   end

   if c1 >= 0xC2 and c1 <= 0xDF then  -- UTF8-2
      return s_char(c1, tail(nextbyte(), c1))
   end

   if c1 == 0xE0 then  -- UTF8-3
      local c2 = nextbyte()
      if c2 >= 0xA0 and c2 <= 0xBF then
         return s_char(c1, c2, tail(nextbyte(), c1, c2))
      end
      error(s_format("Invalid UTF8-3 sequence: U+%02x%02x..", c1, c2))
   elseif c1 == 0xED then
      local c2 = nextbyte()
      if c2 >= 0x80 and c2 <= 0x9F then
         return s_char(c1, c2, tail(nextbyte(), c1, c2))
      end
      error(s_format("Invalid UTF8-3 sequence: U+%02x%02x..", c1, c2))
   elseif c1 >= 0xE1 and c1 <= 0xEC then
      local c2 = tail(nextbyte(), c1)
      return s_char(c1, c2, tail(nextbyte(), c1, c2))
   elseif c1 >= 0xEE and c1 <= 0xEF then
      local c2 = tail(nextbyte(), c1)
      return s_char(c1, c2, tail(nextbyte(), c1, c2))
   end

   if c1 == 0xF0 then  -- UTF8-4
      local c2 = nextbyte()
      if c2 >= 0x90 and c2 <= 0xBF then
         local c3 = tail(nextbyte(), c1, c2)
         return s_char(c1, c2, c3, tail(nextbyte(), c1, c2, c3))
      end
      error(s_format("Invalid UTF8-4 sequence: U+%02x%02x..", c1, c2))
   elseif c1 == 0xF4 then
      local c2 = nextbyte()
      if c2 >= 0x80 and c2 <= 0x8F then
         local c3 = tail(nextbyte(), c1, c2)
         return s_char(c1, c2, c3, tail(nextbyte(), c1, c2, c3))
      end
      error(s_format("Invalid UTF8-4 sequence: U+%02x%02x..", c1, c2))
   elseif c1 >= 0xF1 and c1 <= 0xF3 then
      local c2 = tail(nextbyte(), c1)
      local c3 = tail(nextbyte(), c1, c2)
      return s_char(c1, c2, c3, tail(nextbyte(), c1, c2, c3))
   end

   error(s_format("Invalid UTF8-? sequence: U+%02x..", c1))
end

return decode
