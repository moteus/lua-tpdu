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

local function Bit7Encode(str, pad)
  local len = #str

  -- escape padding byte
  if math.mod(#str, 16) == 0 and str:find('\r$') then
    str = str .. '\r'
  end

  local bytes, res  = {str:byte(1, #str)}, {}

  local i = 1
  while i <= #str do
    local a, b = bytes[i], bytes[i+1]

    local bits  = i % 8
    local rshift = bits - 1
    local lshift = 8 - bits
    assert(bits ~= 0)

    if not b and bits == 7 then
      b = b or pad or 13 -- padding
    end

    if b then
      v = bit.band(b, mask[bits])
      v = bit.band(0xFF, bit.lshift(v, lshift))
    else v = 0 end

    a = bit.rshift(a, rshift)
    v = bit.bor(v, a)

    res[#res + 1] = string.char(v)
    if bits == 7 then i = i + 2
    else i = i + 1 end
  end
  return table.concat(res), len
end

local function Bit7Decode(str)
  local bytes = {str:byte(1, #str)}

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
    local m = math.mod(#res, 8)
    if m == 0 or m == 1  and res[#res-1] == '\r' then
      res[#res] = nil
    end
  end

  return table.concat(res)
end

local function Gsm7Encode(str, pad)
  str = Asci2Gsm(str)
  return Bit7Encode(str, pad)
end

local function Gsm7Decode(str)
  str = Bit7Decode(str)
  return Gsm2Asci(str)
end

return {
  Encode    = Bit7Encode;
  Decode    = Bit7Decode;
  GsmEncode = Gsm7Encode;
  GsmDecode = Gsm7Decode;
}