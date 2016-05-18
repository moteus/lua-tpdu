------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2015-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-tpdu library.
--
------------------------------------------------------------------

local bit    = require "tpdu.utils".bit
local string = require "string"
local table  = require "table"
local math   = require "math"

local mask = {
  -1 + 2^1;
  -1 + 2^2;
  -1 + 2^3;
  -1 + 2^4;
  -1 + 2^5;
  -1 + 2^6;
  -1 + 2^7;
}

-- http://www.developershome.com/sms/gsmAlphabet.asp
local GSM_Encode = {
  ['@']  = string.char(0x00);
  ['$']  = string.char(0x02);
  ['_']  = string.char(0x11);
}

local GSM_Escape_Encode = {
  ['^']  = string.char(0x1B, 0x14);
  ['{']  = string.char(0x1B, 0x28);
  ['}']  = string.char(0x1B, 0x29);
  ['\\'] = string.char(0x1B, 0x2F);
  ['[']  = string.char(0x1B, 0x3C);
  ['~']  = string.char(0x1B, 0x3D);
  [']']  = string.char(0x1B, 0x3E);
  ['|']  = string.char(0x1B, 0x40);
}

local GSM_Decode = {}
for k, v in pairs(GSM_Encode) do GSM_Decode[v] = k end

local GSM_Escape_Decode = {}
for k, v in pairs(GSM_Escape_Encode) do GSM_Escape_Decode[v] = k end

local function Asci2Gsm(str)
  return (str
    :gsub(".", GSM_Encode)
    :gsub(".", GSM_Escape_Encode)
  )
end

local function Gsm2Asci(str)
  return (str
    :gsub(".",    GSM_Decode)
    :gsub("\27.", GSM_Escape_Decode)
  )
end

local function Bit7Encode(str, pad, align)
  local len = #str

  if align then
    align = align % 7
    if align == 0 then
      align = nil
    end
  end

  if pad then
    -- escape padding byte
    if #str % 16 == 0 and str:find('\r$') then
      str = str .. '\r'
    end
  end

  local bytes, res  = {str:byte(1, #str)}, {}

  if pad then
    if not align then
      if #bytes % 7 == 1 then
        bytes[#bytes + 1] = 13
      end
    elseif #bytes % 8 == 0 then
      bytes[#bytes + 1] = 13
    end
  end

  local i = 1
  while i <= #bytes do
    local a, b = bytes[i], bytes[i+1]

    local bits  = i % 8
    local rshift = bits - 1
    local lshift = 8 - bits
    assert(bits ~= 0)

    if b then
      v = bit.band(b, mask[bits])
      v = bit.band(0xFF, bit.lshift(v, lshift))
    else v = 0 end

    a = bit.rshift(a, rshift)
    v = bit.bor(v, a)

    res[#res + 1] = v
    if bits == 7 then i = i + 2
    else i = i + 1 end
  end

  if align then
    local filler = 0
    local m = mask[7 - align]
    for i = 1, #res do
      local next_filler = bit.rshift(res[i], 8 - align)
      res[i] = bit.lshift(res[i], align)
      res[i] = bit.bor(res[i], filler)
      res[i] = bit.band(res[i], 0xFF)
      filler = next_filler
    end
    if #res % 7 == 0 then
      assert(not pad)
      res[#res + 1] = filler
    end
  end

  for i = 1, #res do res[i] = string.char(res[i]) end

  return table.concat(res), len
end

local function Bit7Decode(str, align)
  local bytes = {str:byte(1, #str)}

  if align then
    align = align % 7
    if align > 0 then
      local m = mask[7 - align]
      for i = 1, #bytes do
        local filler = bit.lshift(bytes[i+1] or 0, 8 - align)
        bytes[i] = bit.rshift(bytes[i], align)
        bytes[i] = bit.bor(bytes[i], filler)
        bytes[i] = bit.band(bytes[i], 0xFF)
      end
    end
  end

  local i = 0
  local res = {}
  local bits = 0

  while i < #str do
    local a, b = bytes[i], bytes[i+1]
    a = a or 0

    local bits = 7 - i%7

    local v = bit.band(b, mask[bits])
    v = bit.lshift(v, 7 - bits)
    a = bit.rshift(a, bits + 1)
    v = bit.bor(v, a)

    res[#res + 1] = string.char(v)
    if bits == 1 then
      res[#res + 1] = string.char(bit.rshift(b, 1))
    end
    i = i + 1
  end

  if res[#res] == '\r'  then
    local m = #res % 8
    if m == 0 or m == 1  and res[#res-1] == '\r' then
      res[#res] = nil
    end
  end

  return table.concat(res)
end

local function Gsm7Encode(str, ...)
  str = Asci2Gsm(str)
  return Bit7Encode(str, ...)
end

local function Gsm7Decode(str, ...)
  str = Bit7Decode(str, ...)
  return Gsm2Asci(str)
end

return {
  Encode    = Bit7Encode;
  Decode    = Bit7Decode;
  GsmEncode = Gsm7Encode;
  GsmDecode = Gsm7Decode;
  Asci2Gsm  = Asci2Gsm;
  Gsm2Asci  = Gsm2Asci;
}