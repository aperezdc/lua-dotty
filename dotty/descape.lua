--
-- descape.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Parses input from a (TTY-alike) terminal.
--
-- Distributed under terms of the MIT license.
--

local unidecode = require "dotty.unidecode"

local ascii = require "dotty.asciicodes"
local ESC, CAN, SUB, QMARK = ascii.ESC, ascii.CAN, ascii.SUB, ascii.QMARK
local SEMICOLON, LBRACKET = ascii.SEMICOLON, ascii.LBRACKET
local DIGIT_0, DIGIT_9 = ascii.DIGIT_0, ascii.DIGIT_9

local s_char = string.char
local error, pcall, type, t_insert = error, pcall, type, table.insert
local unpack, pack = table.unpack or unpack, table.pack or function (...)
   local n = select("#", ...)
   local t = { n = n }
   for i = 1, n do
      t[i] = select(1, ...)
   end
   return t
end

local function d_error(delegate, format, ...)
   local message = format:format(...)
   if delegate and type(delegate.parse_error) == "function" then
      delegate:parse_error(message)
   end
   -- Raise the error anyway, just in case the delegate does not.
   error(message)
end

local function d_warning(delegate, format, ...)
   if delegate and type(delegate.warning) == "function" then
      delegate:warning(format:format(...))
   end
end

local function d_debug(delegate, format, ...)
   if delegate and type(delegate.debug) == "function" then
      delegate:debug(format:format(...))
   end
end

local function invoke_pack(f, ...)
   return pack(f(...))
end

local function d_invoke_ret(delegate, name, ...)
   local handler = delegate[name]
   if handler then
      local ok, p = pcall(invoke_pack, handler, delegate, ...)
      if ok then return unpack(p) end
      d_error(delegate, "error in delegate handler %q: %s", name, p[1])
   else
      d_warning(delegate, "no delegate handler for %q", name)
   end
end

local function d_invoke(delegate, name, ...)
   if delegate then
      local handler = delegate[name]
      if handler then
         local ok, err = pcall(handler, delegate, ...)
         if not ok then
            d_error(delegate, "error in delegate handler %q: %s", name, err)
         end
      else
         d_warning(delegate, "no delegate handler for %q", name)
      end
   end
end

local decode, decode_escape -- Forward declarations.

local function parse_csi_params(nextbyte, delegate)
   local params = {}
   local imm
   local c = nextbyte()
   if c == nil then return end

   if c == QMARK then
      d_debug(delegate, "parse_csi_params: '%c' (0x%02X) - QMARK", c, c)
      imm, c = c, nextbyte()
      if c == nil then return end
   end

   d_debug(delegate, "parse_csi_params: '%c' (0x%02X) - BEGIN", c, c)

   while c >= DIGIT_0 and c <= DIGIT_9 do
      -- Discard leading zeroes.
      while c == DIGIT_0 do
         c = nextbyte()
         if c == nil then return end
         d_debug(delegate, "parse_csi_params: '%c' (0x%02X) - 0-DISCARD", c, c)
      end

      local result = 0
      local multiplier = 1
      while c >= DIGIT_0 and c <= DIGIT_9 do
         result = result * multiplier + c - DIGIT_0
         multiplier = multiplier * 10
         c = nextbyte()
         if c == nil then return end
         d_debug(delegate, "parse_csi_params: '%c' (0x%02X) LOOP, r=%d, m=%d", c, c, result, multiplier)
      end
      t_insert(params, result)

      -- Advance
      if c == SEMICOLON then
         c = nextbyte()
         if c == nil then return end
      end
   end

   d_debug(delegate, "parse_csi_params: #param=%d, c=%s, imm=%s", #params, c, imm)
   return params, c, imm
end

-- See: http://www.leonerd.org.uk/hacks/fixterms/
local csi_tilde_translation = {
   [2]  = "key_insert",
   [3]  = "key_delete",
   [5]  = "key_pageup",
   [6]  = "key_pagedown",
   [7]  = "key_home",
   [8]  = "key_end",
   [11] = "key_f1",
   [12] = "key_f2",
   [13] = "key_f3",
   [14] = "key_f4",
   [15] = "key_f5",
   [17] = "key_f6",
   [18] = "key_f7",
   [19] = "key_f8",
   [20] = "key_f9",
   [21] = "key_f10",
   [23] = "key_f11",
   [24] = "key_f12",
}

local function csi_add_modifier_flags(params, handler_name)
   local t = { shift = false, ctrl = false, alt = false }
   local code = params[2]
   if code == 2 then
      t.shift = true
   elseif code == 3 then
      t.alt = true
   elseif code == 4 then
      t.shift, t.alt = true, true
   elseif code == 5 then
      t.ctrl = true
   elseif code == 6 then
      t.shift, t.ctrl = true, true
   elseif code == 7 then
      t.ctrl, t.alt = true, true
   end
   return handler_name, t, params[1] or 1
end

local csi_final_chars = {
   [ascii.R] = function (params)
      return "cursor_position_reported", params[1] or 1, params[2] or 1
   end,

   [ascii.x] = function (params)
      if params.n ~= 7 then
         assert(params.n == 6)
         for i = 6, 1, -1 do
            params[i + 1] = params[i]
         end
         params[1], params.n = 0, 7
      end
      return "terminal_parameters_reported", unpack(params)
   end,

   [ascii.n] = function (params)
      return "device_status_reported", (params.n == 1) and params[1] or 0
   end,

   [ascii.A] = function (p) return csi_add_modifier_flags(p, "key_up") end,
   [ascii.B] = function (p) return csi_add_modifier_flags(p, "key_down") end,
   [ascii.C] = function (p) return csi_add_modifier_flags(p, "key_right") end,
   [ascii.D] = function (p) return csi_add_modifier_flags(p, "key_left") end,
   [ascii.TILDE] = function (params)
      local handler_name = csi_tilde_translation[params[1]]
      if handler_name then
         return csi_add_modifier_flags(params, handler_name)
      end
   end,
}

local csi_imm_final_chars = {
   [ascii.QMARK] = {
      [ascii.c] = function (params)
         -- XXX: Is it okay to ignore params[1]?
         return "device_attributes_reported", params[2] or 0
      end,
   },
}

local function decode_csi_sequence(nextbyte, delegate)
   -- TODO: Move code from parse_csi_params() here.
   local params, code, imm = parse_csi_params(nextbyte, delegate)
   if not params then return end

   local handler_name = imm and csi_imm_final_chars[imm][code]
                             or csi_final_chars[code]
   if handler_name then
      -- A function handler might mangle params in-place.
      if type(handler_name) == "function" then
         d_invoke(delegate, handler_name(params))
      else
         d_invoke(delegate, handler_name, unpack(params))
      end
   elseif code >= 0 then
      if imm then
         d_warning(delegate,
                   "no CSI sequence handler for %q (0x%02X), imm %q (0x%02X)",
                   s_char(code), code,
                   s_char(imm), imm)
      else
         d_warning(delegate,
                   "no CSI sequence handler for %q (0x%02X)",
                   s_char(code),
                   code)
       end
   end
end

local simple_escapes = { [ascii.O] = {} }

local function add_vt52_and_ansi(byte, name)
   local handler = function (nextbyte, delegate)
      d_invoke(delegate, csi_add_modifier_flags({}, name))
   end
   simple_escapes[byte] = handler           -- VT52 mode.
   simple_escapes[ascii.O][byte] = handler  -- ANSI+CursorKey mode.
end

add_vt52_and_ansi(ascii.A, "key_up")
add_vt52_and_ansi(ascii.B, "key_down")
add_vt52_and_ansi(ascii.C, "key_right")
add_vt52_and_ansi(ascii.D, "key_left")
add_vt52_and_ansi(ascii.F, "key_end")
add_vt52_and_ansi(ascii.H, "key_home")
add_vt52_and_ansi(ascii.P, "key_f1")
add_vt52_and_ansi(ascii.Q, "key_f2")
add_vt52_and_ansi(ascii.R, "key_f3")
add_vt52_and_ansi(ascii.S, "key_f4")
add_vt52_and_ansi = nil


local DISCARD_ESCAPE  = 0x30
local DISCARD_CONTROL = 0x40

-- According to ANSI X3.64, format is "ESC I ... I F" where:
--
--  * I: An intermediate character in an escape sequence or a control
--    sequence, where I is from 40 (octal) to 57 (octal) inclusive.
--
--  * F: A final character in:
--      - An escape sequence, where F is from 60 (octal) to 176 (octal)
--        inclusive.
--      - A control sequence, where F is from 100 (octal) to 176 (octal)
--        inclusive.
--
-- For simplicity, we discard any characters up to a "final character",
-- or a CAN or SUB character is find (any of which cancel the escape
-- sequence).
--
local function discard(nextbyte, delegate, f_lo)
   repeat
      local c = nextbyte()
      if c == nil then return end
      if c == ESC then return decode_escape(nextbyte, delegate) end
   until c == CAN or c == SUB or c < f_lo or c > 0x7E
end

-- This was forward-declared
decode_escape = function (nextbyte, delegate)
   local c1 = nextbyte()
   if c1 == nil then return end

   d_debug(delegate, "decode_escape: '%c' (0x%02X)", c1, c1)
   if c1 == LBRACKET then  -- ESC[…
      return decode_csi_sequence(nextbyte, delegate)
   end
   local handler = simple_escapes[c1]
   while type(handler) == "table" do
      local c = nextbyte()
      if c == nil then return end
      d_debug(delegate, "decode_escape: '%c' (0x%02X) - LOOP", c, c)
      handler = handler[c]
   end
   if handler then
      return handler(nextbyte, delegate)
   end
   return discard(nextbyte, delegate, DISCARD_ESCAPE)
end

-- Unterminated escape sequence followed by another escape: ESC ESC …
simple_escapes[ascii.O][ESC] = decode_escape
simple_escapes[ESC] = decode_escape

-- CSI sequence: ESC [ …
simple_escapes[LBRACKET] = decode_csi_sequence

-- This was forward-declared
decode = function (nextbyte, delegate)
   local byte = nextbyte()
   if byte ~= nil and byte == ESC then
      d_debug(delegate, "decode: begin escape sequence")
      return decode_escape(nextbyte, delegate)
   end
   return byte
end


ascii = nil
return {
   decode_csi_sequence = decode_csi_sequence,
   decode_escape = decode_escape,
   decode = decode,
}
