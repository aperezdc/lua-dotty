--
-- asciicodes.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local A = {
   NUL       = 0x00,
   SOH       = 0x01, -- Start Of Heading.
   STX       = 0x02, -- Start Of TeXt.
   ETX       = 0x03, -- End of TeXt.
   EOT       = 0x04, -- End Of Transmission.
   ENQ       = 0x05, -- ENQuiry.
   ACK       = 0x06, -- ACKnowledge.
   BELL      = 0x07, -- Bell.
   BACKSPACE = 0x08, -- Backspace.
   TAB       = 0x09, -- Horizontal Tab.
   NEWLINE   = 0x0A, -- Line Feed.
   VT        = 0x0B, -- Vertical Tab.
   FF        = 0x0C, -- Form Feed.
   CR        = 0x0D, -- Carriage Return.
   SO        = 0x0E, -- Shift Out.
   SI        = 0x0F, -- Shift In.

   DLE       = 0x10, -- Data Link Escape.
   DC1       = 0x11, -- Device Control 1.
   DC2       = 0x12, -- Device Control 2.
   DC3       = 0x13, -- Device Control 3.
   DC4       = 0x14, -- Device Control 4.
   NAK       = 0x15, -- Negative AcKnowledge.
   SYN       = 0x16, -- SYNchronous idle.
   ETB       = 0x17, -- End of Transmission Block.
   CAN       = 0x18, -- CANcel.
   EM        = 0x19, -- End of Medium.
   SUB       = 0x1A, -- SUBstitute.
   ESC       = 0x1B, -- ESCape.
   FS        = 0x1C, -- File Separator.
   GS        = 0x1D, -- Group Separator.
   RS        = 0x1E, -- Record Separator.
   US        = 0x1F, -- Unit Separator.

   SPACE     = 0x20,
   BANG      = 0x21, -- !
   DQUOTE    = 0x22, -- "
   HASH      = 0x23, -- #
   DOLLAR    = 0x24, -- $
   PERCENT   = 0x25, -- %
   AND       = 0x26, -- &
   QUOTE     = 0x27, -- '
   LPAREN    = 0x28, -- (
   RPAREN    = 0x29, -- )
   STAR      = 0x2A, -- *
   PLUS      = 0x2B, -- +
   COMMA     = 0x2C, -- ,
   MINUS     = 0x2D, -- -
   PERIOD    = 0x2E, -- .
   SLASH     = 0x2F, -- /

   -- Digits 0-9 (0x30 - 0x39, generated below).

   COLON     = 0x3A, -- :
   SEMICOLON = 0x3B, -- ;
   LT        = 0x3C, -- <
   EQUAL     = 0x3D, -- =
   GT        = 0x3E, -- >
   QMARK     = 0x3F, -- ?
   AT        = 0x40, -- @

   -- Letters A-Z (0x41 - 0x5A, generated below).

   LBRACKET   = 0x5B, -- [
   BACKSLASH  = 0x5C, -- \
   RBRACKET   = 0x5D, -- ]
   HAT        = 0x5E, -- ^
   UNDERSCORE = 0x5F, -- _
   BACKTICK   = 0x60, -- `

   -- Letters a-z (0x61 - 0x7A, generated below).

   LBRACE     = 0x7B, -- {
   BAR        = 0x7C, -- |
   RBRACE     = 0x7D, -- }
   TILDE      = 0x7E, -- ~
   DEL        = 0x7F, -- DELete
}

for x = 0x30, 0x39 do A["DIGIT_" .. string.char(x)] = x end -- Digits 0-9
for x = 0x41, 0x5A do A[string.char(x)] = x end -- Letters A-Z
for x = 0x61, 0x7A do A[string.char(x)] = x end -- Letters a-z

-- Generate reverse mapping (code to character name).
do local R = {}
   for name, code in pairs(A) do R[code] = name end
   for i = 0, #R do A[i] = R[i] end
end

-- Add some convenience aliases.
A.BEL, A.BS, A.HT = 0x07, 0x08, 0x09

return A
