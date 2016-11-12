--
-- descape-delegate.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local unidecode = require "dotty.unidecode"
local descape = require "dotty.descape"
local ttyctl = require "dotty.ttyctl"
local ascii = require "dotty.asciicodes"
local utf8 = require "dromozoa.utf8"
local wcwidth = require "wcwidth"
local inspect = require "inspect"

--
-- Create a "delegate" to handle escape sequences. Whenever the decoder
-- completes parsing a recognized terminal escape sequence, it invokes
-- methods in the delegate.
--
-- For this example, a reporter function which prints out the parameters
-- passed to the handler is used for each supported event kind. Debugging
-- and warning messages are handling as well and printed out colored.
--
local delegate = {}

if arg[1] == "debug" then
   function delegate:debug(message)
      io.write("\27[36m[debug] \27[37m" .. message .. "\27[0m\n\r")
      io.flush()
   end
end

function delegate:warning(message)
   io.write("\27[33m[warn]\27[0m " .. message .. "\n\r")
   io.flush()
end

-- Factory which installs a reporter method in the delegate.
local inspect_options = { newline = " ", indent = "" }
local function reporter(name)
   delegate[name] = function (self, ...)
      io.write("\27[1m" .. name .. "\27[0m [")
      io.write(tostring(select("#", ...)))
      io.write("]:")
      for i = 1, select("#", ...) do
         io.write(" " .. inspect(select(i, ...), inspect_options))
      end
      io.write("\n\r")
      io.flush()
   end
end

-- Install reporter handlers.
for _, name in ipairs {
   "device_status_reported",
   "device_attributes_reported",
   "cursor_position_reported",
   "key_up", "key_down", "key_right", "key_left",
   "key_f1", "key_f2", "key_f3", "key_f4", "key_f5", "key_f6",
   "key_f7", "key_f8", "key_f9", "key_f10", "key_f11", "key_f12",
   "key_home", "key_end", "key_pageup", "key_pagedown",
   "key_insert", "key_delete",
   "key",
} do reporter(name) end


--
-- This reader is a coroutine which yields one byte of input each time
-- it it resumed, until the input is consumed, and then it returns EOT.
--
local bytereader = coroutine.wrap(function ()
   while true do
      local ch = io.read(1)
      if ch == nil then
         return ascii.EOT
      end
      coroutine.yield(ch:byte())
   end
end)

--
-- Wrap the bytes reader into another which uses descape.decode() to handle
-- decoding of terminal escape sequences. This reader is then used as the
-- reader passed to unidecode(). This arrangement allows for terminal escape
-- sequences to appear in the middle of UTF8 multibyte sequences: when a
-- escape sequence begins, it will be consumed by descape.decode(). The UTF8
-- decoder never gets to "see" the bytes which are part of terminal escape
-- sequences.
--
local unicodereader = coroutine.wrap(function ()
   while true do
      local ch = descape.decode(bytereader, delegate)
      if ch ~= nil then
         if ch == ascii.EOT then
            return ch
         end
         coroutine.yield(ch)
      end
   end
end)


--
-- Use dotty.ttyctl to set the terminal in cbreak mode. This way
-- input is processed as soon as it arrives to the input buffer.
--
ttyctl(io.stdout):with_cbreak(function ()
   io.write("Press Ctrl-D to end the input loop.\n\r")

   -- Request some information from the terminal usin CSI escape sequences.
   io.write("\27[c")  -- What Are You?
   io.write("\27[5n") -- DSR (Device Status Report), report status
   io.write("\27[6n") -- DSR (Device Status Report), report active position
   io.flush()

   while true do
      local input = unidecode(unicodereader)
      local rune = utf8.codepoint(input)
      if rune == ascii.EOT then
         io.write("EOT\n\r")
         break
      end
      -- Leave one extra cell empty after a double-width character.
      local space = (wcwidth(rune) == 2) and " " or ""
      io.write(string.format("\27[1;32minput\27[0;0m: '%s%s' (U+%X, %d)\n\r",
                             input, space, rune, rune))
      io.flush()
   end
end)
