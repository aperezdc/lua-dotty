--
-- ttyctl.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local posix = require "posix"
local bit = (function ()
   local try_modules = { "bit", "bit32" }
   for _, name in ipairs(try_modules) do
      local ok, mod = pcall(require, name)
      if ok then return mod end
   end
   error("no 'bit'-compatible module found (tried: " ..
         table.concat(try_modules, ", ") .. ")")
end)()

local error, type, pairs, tostring = error, type, pairs, tostring
local t_insert, t_concat = table.insert, table.concat
local s_gsub, sprintf = string.gsub, string.format

local function ensure(ok, err, ...)
   if not ok then error(err, 2) end
   return ok, err, ...
end

local function deepcopy(t)
   local n = {}
   for name, value in pairs(t) do
      n[name] = (type(value) == "table") and deepcopy(value) or value
   end
   return n
end

local function file_descriptor(fd)
   if type(fd) == "number" then
      return fd
   end
   if type(fd) == "table" then
      if type(fd.pollfd) == "function" then
         return fd:pollfd()  -- Used by cqueues.
      end
      if type(fd.fileno) == "function" then
         return fd:fileno()
      end
   end
   return posix.fileno(fd)
end

local function formatter0(format)
   return function ()
      return format
   end
end

local function formatter1(format, default1)
   return function (self, arg1)
      return sprintf(format, arg1 or default1)
   end
end

local function formatter2(format, default1, default2)
   return function (self, arg1, arg2)
      return sprintf(format, arg1 or default1, arg2 or default2)
   end
end

local ttyctl = {
   save_cursor     = formatter0(string.char(0x1B) .. "7"),
   restore_cursor  = formatter0(string.char(0x1B) .. "8"),
   cursor_position = formatter2("\27[%d;%dH", 0, 0),
   cursor_up       = formatter1("\27[%dA", 1),
   cursor_down     = formatter1("\27[%dB", 1),
   cursor_right    = formatter1("\27[%dC", 1),
   cursor_left     = formatter1("\27[%dD", 1),
   erase_display   = formatter1("\27[%dJ", 0),
   erase_line      = formatter1("\27[%dK", 0),
}
ttyctl.__index = ttyctl

setmetatable(ttyctl, { __call = function (self, output)
   local fd = file_descriptor(output)
   if not posix.isatty(fd) then
      error(posix.errno(posix.ENOTTY))
   end
   return setmetatable({
      output = output,
      __fd = fd,
      saved_state = false,
      mode = "none",
   }, ttyctl)
end })

function ttyctl:__tostring()
   return "dotty.ttyctl<" .. tostring(self.output) .. ">"
end

local tty_modes = {
   cbreak = function (self, state)
      -- Input modes: no break, no CR to NL, no parity check, no strip char,
      -- no start/stop output control.
      state.iflag = bit.band(state.iflag, bit.bnot(bit.bor(posix.BRKINT,
                                                           posix.ICRNL,
                                                           posix.INPCK,
                                                           posix.ISTRIP,
                                                           posix.IXON)))
      -- Output modes: disable postprocessing
      state.oflag = bit.band(state.oflag, bit.bnot(posix.OPOST))
      -- Control modes: use 8-bit characters.
      state.cflag = bit.bor(state.cflag, posix.CS8)
      -- Local modes: echo off, canononical off, no extended functions,
      -- no signal characters (Ctrl-Z, Ctrl-C)
      state.lflag = bit.band(state.lflag, bit.bnot(bit.bor(posix.ECHO,
                                                           posix.ICANON,
                                                           posix.IEXTEN,
                                                           posix.ISIG)))
      -- Return condition: no timeout, one byte at a time
      state.cc[posix.VTIME] = 0
      state.cc[posix.VMIN] = 1
   end,
}

local function tty_restore(self)
   if self.mode == "none" then
      return true
   end
   assert(self.saved_state)
   if posix.tcsetattr(self.__fd, posix.TCSANOW, self.saved_state) ~= 0 then
      return false, posix.errno()
   end
   self.saved_state = false
   self.mode = "none"
   return true
end

local function tty_configure(self, mode)
   if self.mode == mode then
      return true
   end

   local mode_func = tty_modes[mode]
   if not mode_func then
      return false, "invalid mode requested"
   end

   ensure(tty_restore(self))

   self.saved_state = ensure(posix.tcgetattr(self.__fd))
   local state = deepcopy(self.saved_state)
   assert(pcall(mode_func, self, state))

   if posix.tcsetattr(self.__fd, posix.TCSANOW, state) ~= 0 then
      self.saved_state = false
      return false, posix.errno()
   end
   self.mode = mode
   return true
end

ttyctl.restore = tty_restore

function ttyctl:cbreak()
   return tty_configure(self, "cbreak")
end

function ttyctl:with_cbreak(f, ...)
   ensure(tty_configure(self, "cbreak"))
   local ok, err = pcall(f, ...)
   ensure(tty_restore(self))
   if not ok then
      error(err)
   end
end

local ttyctl_context = {}
ttyctl_context.__index = ttyctl_context

setmetatable(ttyctl_context, { __call = function (self, ctl)
   return setmetatable({
      _ctl = ctl,
      _sgr = false,
      _cursor_position = false,
   }, self)
end })

function ttyctl_context:__tostring()
   return "dotty.ttyctl.context<" .. tostring(self._ctl) .. ">"
end

function ttyctl_context:_append(escape_sequence, do_not_escape)
   if not do_not_escape then
      escape_sequence = (s_gsub(escape_sequence, "%%", "%%%%"))
   end
   t_insert(self, escape_sequence)
   return self
end

function ttyctl_context:red(fmt)
   if fmt then
      return self:_append("\27[1;31m"):_append(fmt, true):_append("\27[0;0m")
   else
      self._sgr = true
      return self:_append("\27[1;31m")
   end
end

function ttyctl_context:green(fmt)
   if fmt then
      return self:_append("\27[1;32m"):_append(fmt, true):_append("\27[0;0m")
   else
      self._sgr = true
      return self:_append("\27[1;32m")
   end
end

function ttyctl_context:format(fmt)
   return self:_append(fmt, true)
end

function ttyctl_context:location(x, y)
   if self._cursor_position then
      error("cannot set cursor position more than once")
   end
   self._cursor_position = true
   return self:_append(self._ctl:cursor_position(x, y))
end

function ttyctl_context:formatter()
   local ctl = self._ctl
   local fmt = t_concat(self)
   if self._cursor_position then
      fmt = fmt .. ctl:restore_cursor()  -- XXX: %-escape?
   end
   if self._sgr then
      fmt = fmt .. "\27[0;0m"
   end
   return function (...)
      return sprintf(fmt, ...)
   end
end

function ttyctl_context:writer(output)
   if not output then
      output = self._ctl.output
   end
   local formatter = self:formatter()
   return function (...)
      output:write(formatter(...))
      output:flush()
   end
end

function ttyctl:builder()
   return ttyctl_context(self)
end

return ttyctl
