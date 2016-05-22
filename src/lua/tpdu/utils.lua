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

local bit    = require "tpdu.bit"
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

local PDUError = class() do

local ERRORS = {
  EFORMAT = -1;
}

function PDUError:__init(msg)
  self._no   = ERRORS.EFORMAT
  self._name = 'EFORMAT'
  self._msg  = assert(msg)
  self._ext  = ext
  return self
end

function PDUError:cat()  return 'TPDU' end

function PDUError:no()   return self._no    end

function PDUError:name() return self._name end

function PDUError:msg()  return self._msg end

function PDUError:ext()  return self._ext   end

function PDUError:__eq(rhs)
  return (self._no == rhs._no) and (self._name == rhs._name)
end

function PDUError:__tostring()
  local err = string.format("[%s][%s] %s (%d)",
    self:cat(), self:name(), self:msg(), self:no()
  )
  if self:ext() then
    err = string.format("%s - %s", err, self:ext())
  end
  return err
end

end

return {
  bit     = bit;
  hex2bin = hex2bin;
  bin2hex = bin2hex;
  GetBits = GetBits;
  SetBits = SetBits;
  class   = class;
  error   = PDUError.new;
}