#! /usr/bin/env lua
--
-- ttyctl-withstack.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local ttyctl = require "dotty.ttyctl" (io.stdout)
local hello = ttyctl:builder()
                    :red("Hello, ")
                    :green("%s\r\n")
                    :writer()
local atpos = ttyctl:builder()
                    :location(5, 10)
                    :format("%s")
                    :writer()

ttyctl:with_cbreak(function ()
   ttyctl.output:write(ttyctl:erase_display(2))
   ttyctl.output:write(ttyctl:cursor_position(5, 5))
   atpos("Moved!")
   io.read(1)
   hello("world")
   io.read(1)
   hello("Lua")
   io.read(1)
   ttyctl.output:write(ttyctl:erase_display(2))
end)

