#! /usr/bin/env lua
--
-- ttyctl-getch.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local ttyctl = require "dotty.ttyctl"

local function getch()
   local c
   ttyctl(io.stdout):with_cbreak(function ()
      c = io.read(1)
   end)
   return c
end

io.write("Press any key to continue...")
io.flush()
getch()
io.write("\n")

io.write("Do you want to exit? [y/n]: ")
io.flush()
local response
repeat
   response = getch()
until response == "y" or response == "n"
print(response)
