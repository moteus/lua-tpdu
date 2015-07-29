local bit    = require "bit32"
local string = require "string"
local table  = require "table"
local math   = require "math"

local function bin2hex(str)
  local t = {string.byte(str, 1, #str)}
  for i = 1, #t do t[i] = string.format('%.2X', t[i]) end
  return table.concat(t)
end

local function hex2bin(str)
  str = str:gsub("(..)", function(ch)
    local a = tonumber(ch, 16)
    return string.char(a)
  end)
  return str
end

local mask = {
  -1 + 2^1;
  -1 + 2^2;
  -1 + 2^3;
  -1 + 2^4;
  -1 + 2^5;
  -1 + 2^6;
  -1 + 2^7;
}

local function GetBits(octet, off, n)
  return bit.band(mask[n or 1], bit.rshift(octet, off));
end

local function SetBits(octet, off, v, default)
  if type(v) == 'boolean' then
    if not v then return octet end
    v = 1
  end

  return bit.bor(octet, bit.lshift(v or default, off))
end

local function class(base)
  local t = base and setmetatable({}, base) or {}
  t.__index = t
  t.__class = t
  t.__base  = base

  function t.new(...)
    local o = setmetatable({}, t)
    if o.__init then
      if t == ... then -- we call as Class:new()
        return o:__init(select(2, ...))
      else             -- we call as Class.new()
        return o:__init(...)
      end
    end
    return o
  end

  return t
end

return {
  bit     = bit;
  hex2bin = hex2bin;
  bin2hex = bin2hex;
  GetBits = GetBits;
  SetBits = SetBits;
  class   = class;
}