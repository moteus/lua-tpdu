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

local utils = require "tpdu.utils"
local Bit7  = require "tpdu.bit7"
local Bcd   = require "tpdu.bcd"
local bit   = utils.bit

local Bit7Encode, Bit7Decode = Bit7.Encode, Bit7.Decode
local Gsm7Encode, Gsm7Decode = Bit7.GsmEncode, Bit7.GsmDecode
local BcdDecode, BcdEncode = Bcd.Decode, Bcd.Encode

local hex2bin, bin2hex = utils.hex2bin, utils.bin2hex
local GetBits, SetBits = utils.GetBits, utils.SetBits
local ferror = function(...)
  return utils.error(string.format(...))
end

local Iter = utils.class() do

function Iter:__init(s)
  assert(type(s) == "string")

  self._s = s
  self._i = 1
  return self
end

function Iter:rest()
  if self._i > #self._s then return 0 end
  return #self._s - self._i + 1
end

function Iter:peek_char(n)
  n = n or 1
  return self._s:sub(self._i, self._i + n - 1)
end

function Iter:read_char(n)
  local s = self:peek_char(n)
  self._i = self._i + #s
  return s
end

function Iter:peek_byte()
  return tonumber(self:peek_char(2), 16)
end

function Iter:read_byte()
  return tonumber(self:read_char(2), 16)
end

function Iter:read_str(n)
  local str = self:read_char(n*2)
  str = str:gsub("(..)", function(ch)
    local a = tonumber(ch, 16)
    return string.char(a)
  end)
  return str
end

end

local TON = { -- TYPEOFNUMBER
  UNKNOWN        = 0,
  INTERNTIONAL   = 1,
  NATIONAL       = 2,
  NETWORK        = 3,
  SUBSCRIBER     = 4,
  ALPHANUMERIC   = 5,
  ABBREVIATED    = 6,
  RESERVED       = 7
}

local NPI = { -- NUMBERINGPLANIDENTIFICATION
  UNKNOWN    = 0,
  ISDN       = 1,
  X121       = 3,
  TELEX      = 4,
  NATIONAL   = 8,
  PRIVATE    = 9,
  ERMES      = 10,
  RESERVED   = 15,
}

local MTI = { -- message type id 
  DELIVER            = 0;
  SUBMIT             = 1;
  COMMAND            = 2;

  ["DELIVER-REPORT"] = 0;
  ["SUBMIT-REPORT"]  = 1;
  STATUS             = 2;

  ANY                = 3;
}

local SMS_CLASS = {
  CLASS_NONE,
  CLASS_0,
  CLASS_1,
  CLASS_2,
  CLASS_3,
}

local DCS_CODEC = {
  BIT7     = 0,
  BIT8     = 1,
  UCS2     = 2,
  RESERVED = 3,
}

local DCS_GROUP = {
  DCS_GROUP_0,
  DCS_GROUP_6,
}

local function find(t, val)
  for k, v in pairs(t) do
    if k:lower() == val or k == val or v == val then
      return k, v
    end
  end
end

local STInfo do

local ST_SUCCESS = { -- Short message transaction completed
  [0] = 'Short message received by the SME',
  [1] = 'Short message forwarded by the SC to the SME but the SC is unable to confirm delivery',
  [2] = 'Short message replaced by the SC',
}

local ST_RESERVED = { -- Reserved values
  [{03, 15}] = 'Reserved',
  [{16, 31}] = 'Values specific to each SC',
}

local ST_TEMP_FAIL = { -- Temporary error, SC still trying to transfer SM
  [32]     = 'Congestion',
  [33]     = 'SME busy',
  [34]     = 'No response from SME',
  [35]     = 'Service rejected',
  [36]     = 'Quality of service not available',
  [37]     = 'Error in SME',
  [{38, 47}] = 'Reserved',
  [{48, 63}] = 'Values specific to each SC',
}

local ST_FAIL = { -- Permanent error, SC is not making any more transfer attempts
  [64]       = 'Remote procedure error',
  [65]       = 'Incompatible destination',
  [66]       = 'Connection rejected by SME',
  [67]       = 'Not obtainable',
  [68]       = 'Quality of service not available',
  [69]       = 'No interworking available',
  [70]       = 'SM Validity Period Expired',
  [71]       = 'SM Deleted by originating SME',
  [72]       = 'SM Deleted by SC Administration',
  [73]       = 'SM does not exist (The SM may have previously existed in the SC but the SC no longer has knowledge of it or the SM may never have previously existed in the SC)',
  [{74, 79}] = 'Reserved',
  [{80, 95}] = 'Values specific to each SC',
}

local ST_RECOVERED_FAIL = { -- Temporary error, SC is not making any more transfer attempts
  [96 ]        = 'Congestion',
  [97 ]        = 'SME busy',
  [98 ]        = 'No response from SME',
  [99 ]        = 'Service rejected',
  [100]        = 'Quality of service not available',
  [101]        = 'Error in SME',
  [{102, 105}] = 'Reserved',
  [{106, 111}] = 'Reserved',
  [{112, 127}] = 'Values specific to each SC',
}

local function find_status(t, s)
  if t[s] then return t[s] end
  for k, v in pairs(t) do
    if type(k) == 'table' then
      if k[1] <= s and k[2] >= s then
        return v
      end
    end
  end
end

STInfo = function(status)
  local res = {
    status    = status,
    success   = false,
    temporary = false,
    recovered = false,
    info      = nil,
  }

  res.info = find_status(ST_SUCCESS, status)
  if res.info then
    res.success = true
    return res
  end

  res.info = find_status(ST_TEMP_FAIL, status)
  if res.info then
    res.temporary = true
    return res
  end

  res.info = find_status(ST_RECOVERED_FAIL, status)
  if res.info then
    res.recovered = true
    return res
  end

  res.info = find_status(ST_FAIL, status) or find_status(ST_RESERVED, status)

  return res
end

end

local function SCADecode(iter)
  local len  = iter:read_byte()
  if len == 0 then return {} end
  assert(len > 1)

  local toa    = iter:read_byte()
  local plan   = GetBits(toa, 0, 4)
  local type   = GetBits(toa, 4, 3)

  local sca = {
    ton    = find(TON, type);
    npi    = find(NPI, plan);
    number = iter:read_char((len-1) * 2)
  }

  if sca.ton == 'ALPHANUMERIC' then
    sca.number = Gsm7Decode(hex2bin(sca.number))
  else
    sca.number = BcdDecode(sca.number)
    if sca.ton == 'INTERNTIONAL' then
      sca.number = '+' .. sca.number
    end
    sca.number = sca.number:gsub('F$', '')
  end

  return sca
end

local function SCAEncode(sca)
  if type(sca) == 'string' then sca = {number = sca} end

  if not (sca and sca.number) then return '00' end

  local ton, npi, res, _ = sca.ton, sca.npi, 0x80
  if not ton then
    if sca.number:find("^%+%d+$") then
      ton = TON.INTERNTIONAL
    elseif sca.number:find("^%d+$") then
      ton = TON.NATIONAL
    else
      ton = ALPHANUMERIC
    end
  end
  if not npi then
    if ton == ALPHANUMERIC then
      npi = NPI.UNKNOWN
    else
      npi = NPI.ISDN
    end
  end

  _, ton = find(TON, ton)
  _, npi = find(NPI, npi)

  local toa = bit.bor(res, npi, bit.lshift(ton, 4))

  local number = sca.number
  if ton == TON.ALPHANUMERIC then
    number = bin2hex(Gsm7Encode(number))
  else
    if ton == TON.INTERNTIONAL then
      number = number:gsub('^%+', '')
    end
    number = BcdEncode(number)
  end

  local len = bit.rshift(#number, 1) + 1
  return string.format("%.2X%.2X%s", len, toa, number)
end

local function PDUTypeDecode(iter, direct)
  local v = iter:read_byte()

  local tp = {
    mti = GetBits(v, 0, 2);
  }

  if direct == 'input' then -- from smsc
        if tp.mti == MTI.DELIVER           then tp.mti = 'DELIVER'
    elseif tp.mti == MTI['SUBMIT-REPORT']  then tp.mti = 'SUBMIT-REPORT'
    elseif tp.mti == MTI.STATUS            then tp.mti = 'STATUS'
    else tp.mti = 'ANY' end
  else
        if tp.mti == MTI.SUBMIT            then tp.mti = 'SUBMIT'
    elseif tp.mti == MTI['DELIVER-REPORT'] then tp.mti = 'DELIVER-REPORT'
    elseif tp.mti == MTI.COMMAND           then tp.mti = 'COMMAND'
    else tp.mti = 'ANY' end
  end

  if tp.mti == 'SUBMIT' then
    tp.rd   = GetBits(v, 2)    ~= 0;
    tp.vpf  = GetBits(v, 3, 2);
    tp.srr  = GetBits(v, 5)    ~= 0;
    tp.udhi = GetBits(v, 6)    ~= 0;
    tp.rp   = GetBits(v, 7)    ~= 0;
  end

  if tp.mti == 'DELIVER' then
    tp.mms  = GetBits(v, 2)    ~= 0;
    tp.sri  = GetBits(v, 5)    ~= 0;
    tp.udhi = GetBits(v, 6)    ~= 0;
    tp.rp   = GetBits(v, 7)    ~= 0;
  end

  if tp.mti == 'STATUS' then
    tp.mms  = GetBits(v, 2)    ~= 0;
    tp.srq  = GetBits(v, 5)    ~= 0;
  end

  return tp
end

local function PDUTypeEncode(tp, pdu)
  local v = 0

  local mti = tp.mti or 'SUBMIT'
  local _, m = find(MTI, mti)

  local vpf = tp.vpf
  if not vpf then
    if pdu.vp then
      vpf = (type(pdu.vp) == 'number') and 2 or 3
    end
  end

  local udhi = tp.udhi
  if nil == udhi then
    udhi = not not pdu.udh
  end

  v = SetBits(v, 0, m)

  if mti == 'SUBMIT' then
    v = SetBits(v, 2, tp.rd,   0)
    v = SetBits(v, 3, vpf,     0)
    v = SetBits(v, 5, tp.srr,  0)
    v = SetBits(v, 6, udhi,    0)
    v = SetBits(v, 7, tp.rp,   0)
  end

  if tp.mti == 'DELIVER' then
    v = SetBits(v, 2, tp.mms,  0)
    v = SetBits(v, 5, tp.sri,  0)
    v = SetBits(v, 6, tp.udhi, 0)
    v = SetBits(v, 7, tp.rp,   0)
  end

  if tp.mti == 'STATUS' then
    v = SetBits(v, 2, tp.mms,  0)
    v = SetBits(v, 5, tp.srq,  0)
  end

  return string.format('%.2X', v)
end

local function AddressDecode(iter)
  local len = iter:read_byte()
  local toa = iter:read_byte()

  local plan   = GetBits(toa, 0, 4)
  local type   = GetBits(toa, 4, 3)

  local addr = {
    ton    = find(TON, type);
    npi    = find(NPI, plan);
  }

  if addr.ton == 'ALPHANUMERIC' then
    local chars = math.ceil(len / 2) * 2
    local n = iter:read_char(chars)
    addr.number = Gsm7Decode(hex2bin(n))
    local symbols = math.floor(len * 4 / 7)
    addr.number = addr.number:sub(1, symbols)
  else
    local bytes = math.ceil(len/2) * 2
    local n = iter:read_char(bytes)
    addr.number = BcdDecode(n):sub(1, len)
  end

  if addr.ton == 'INTERNTIONAL' then
    addr.number = '+' .. addr.number
  end

  return addr
end

local function AddressEncode(addr)
  if type(addr) == 'string' then addr = {number = addr} end

  assert(addr.number)

  local ton, npi, res, _ = addr.ton, addr.npi, 0x80
  if not ton then
    if addr.number:find("^%+%d+$") then
      ton = TON.INTERNTIONAL
    elseif addr.number:find("^%d+$") then
      ton = TON.NATIONAL
    else
      ton = ALPHANUMERIC
    end
  end
  if not npi then
    if ton == ALPHANUMERIC then
      npi = NPI.UNKNOWN
    else
      npi = NPI.ISDN
    end
  end

  _, ton = find(TON, ton)
  _, npi = find(NPI, npi)

  local toa = bit.bor(res, npi, bit.lshift(ton, 4))

  local number, len = addr.number
  if ton == TON.ALPHANUMERIC then
    number = bin2hex(Gsm7Encode(number))
    len = math.ceil((#addr.number * 7)/4)
  else
    if ton == TON.INTERNTIONAL then
      number = number:gsub('^%+', '')
    end
    len = #number
    number = BcdEncode(number)
  end

  return string.format("%.2X%.2X%s", len, toa, number)
end

local function DCSDecode(iter)
  local v = iter:read_byte()
  local group, compressed, class, codec, indication

  if v == 0 then
    group      = 0
    compressed = false
    codec      = 'BIT7'
  else
    group = GetBits(v, 6, 2)
    if group == 0 then
      compressed = GetBits(v, 5) == 1
      if GetBits(v, 4) == 1 then
        class = GetBits(v, 0, 2)
      end
      codec = find(DCS_CODEC, GetBits(v, 2, 2))
    elseif group == 3 then
      local typ = GetBits(v, 4, 2)
      compressed = false
      if typ == 3 then
        local reserved = GetBits(v, 3) == 1
        if reserved then return nil, ferror('invalid DCS byte: %.2X', v) end

        group = 'DATA'
        codec = (GetBits(v, 2) == 0) and 'BIT7' or 'BIT8'
        class = GetBits(v, 0, 2)
      else
        local reserved = GetBits(v, 2) == 1
        if reserved then return nil, ferror('invalid DCS byte: %.2X', v) end

        if typ == 0 then     group, codec = 'DISCARD', 'BIT7'
        elseif typ == 1 then group, codec = 'STORE',   'BIT7'
        elseif typ == 2 then group, codec = 'STORE',   'UCS2'
        end

        if GetBits(v, 3) == 1 then
          indication = GetBits(v, 0, 2)
        else
          indication = 'NONE'
        end
      end
    else -- reserved
      return nil, ferror('invalid DCS byte: %.2X', v)
    end
  end

  return{
    group = group,
    compressed = compressed,
    class = class,
    codec = codec,
    indication = indication,
  }
end

local function DCSEncode(dcs)
  if not dcs or not next(dcs) then return '00' end

  local group      = dcs.group or 0
  local compressed = not not dcs.compressed
  local class      = dcs.class or 'NONE'
  local codec      = find(DCS_CODEC, dcs.codec or 'BIT7')
  local indication = dcs.indication or 'NONE'

  if group == 0 and compressed == false and class == 'NONE' and codec == 'BIT7' then
    return '00'
  end

  local v = 0
  if group == 0 then
    v = SetBits(v, 5, compressed)
    if class ~= 'NONE' then
      v = SetBits(v, 4, 1)
      v = SetBits(v, 0, class)
    end
    local _, codec = find(DCS_CODEC, codec)
    v = SetBits(v, 2, codec)
  else
    if group == 'DATA' then -- group = 1100 0000 typ = 0011 0000
      v = 0xF0
      if codec == 'BIT8' then v = SetBits(v, 2, 1)     end
      if class ~= 'NONE' then v = SetBits(v, 0, class) end
    else
      if   group == 'DISCARD' and codec == 'BIT7' then
        v = 0xC0
      elseif group == 'STORE' and codec == 'BIT7' then
        v = 0xD0
      elseif group == 'STORE' and codec == 'UCS2' then
        v = 0xE0
      else
        assert('invalid dcs')
      end
      if indication and indication ~= 'NONE' then
        v = SetBits(v, 3, 1)
        v = SetBits(v, 0, indication)
      end
    end
  end
  return string.format('%.2X', v)
end

local LANG = {
  -- 3GPP TS 23.038 V13.0.0 (2015-12)
  [0] = { -- group 0
    [0 ] = 'DE';
    [1 ] = 'EN';
    [2 ] = 'IT';
    [3 ] = 'FR';
    [4 ] = 'ES';
    [5 ] = 'NL';
    [6 ] = 'SV';
    [7 ] = 'DA';
    [8 ] = 'PT';
    [9 ] = 'FI';
    [10] = 'NN';
    [11] = 'EL';
    [12] = 'TR';
    [13] = 'HU';
    [14] = 'PL';
  };
  [2] = {
    [0] = 'CS';
    [1] = 'HE';
    [2] = 'AR';
    [3] = 'RU';
    [4] = 'IS';
  }
}

local LANG_INVERT = {
  -- 3GPP TS 23.038 V13.0.0 (2015-12)
  [0] = { -- group 0
    ['DE'] = 0 ;
    ['EN'] = 1 ;
    ['IT'] = 2 ;
    ['FR'] = 3 ;
    ['ES'] = 4 ;
    ['NL'] = 5 ;
    ['SV'] = 6 ;
    ['DA'] = 7 ;
    ['PT'] = 8 ;
    ['FI'] = 9 ;
    ['NN'] = 10;
    ['EL'] = 11;
    ['TR'] = 12;
    ['HU'] = 13;
    ['PL'] = 14;
  };
  [2] = {
    ['CS'] = 0;
    ['HE'] = 1;
    ['AR'] = 2;
    ['RU'] = 3;
    ['IS'] = 4;
  }
}

local LANG_CODES = {
  ['DE'] = 'German';
  ['EN'] = 'English';
  ['IT'] = 'Italian';
  ['FR'] = 'French';
  ['ES'] = 'Spanish';
  ['NL'] = 'Dutch';
  ['SV'] = 'Swedish';
  ['DA'] = 'Danish';
  ['PT'] = 'Portuguese';
  ['FI'] = 'Finnish';
  ['NN'] = 'Norwegian';
  ['EL'] = 'Greek';
  ['TR'] = 'Turkish';
  ['HU'] = 'Hungarian';
  ['PL'] = 'Polish';
  ['CS'] = 'Czech';
  ['HE'] = 'Hebrew';
  ['AR'] = 'Arabic';
  ['RU'] = 'Russian';
  ['IS'] = 'Icelandic';
}

local CBC_DCS_CODEC = { [0] = 'BIT7', [1] = 'BIT8', [2] = 'UCS2' }
local function DCSBroadcastDecode(v)
  local group, lang, class, codec, compressed, rsv
  group = GetBits(v, 4, 4)

  if group == 1 then -- 3GPP TS 23.038 V13.0.0 (2015-12)
    local bits = GetBits(v, 0, 4)
    if bits > 1 then return nil, ferror('reserved codec value: %.2X', v) end
    codec = (bits == 0) and 'BIT7' or 'UCS2'

    -- GSM 7 bit default alphabet; message preceded by language indication. 
    -- The first 3 characters of the message are a two-character representation of 
    -- the language encoded according to ISO 639 [12], followed by a CR character.
    -- The CR character is then followed by 90 characters of text. 

    -- UCS2; message preceded by language indication
    -- The message starts with a two GSM 7-bit default alphabet character 
    -- representation of the language encoded according to ISO 639 [12]. 
    -- This is padded to the octet boundary with two bits set to 0 and 
    -- then followed by 40 characters of UCS2-encoded message.

  elseif group <= 3 then
    lang = GetBits(v, 0, 4)
    codec = 'BIT7'
  elseif group <= 7 then -- 01xx xxxx
    compressed = GetBits(v, 5) == 1
    local reserved = GetBits(v, 4)
    codec = CBC_DCS_CODEC[GetBits(v, 2, 2)]
    if not codec then return nil, ferror('reserved codec value: %.2X', v) end
    local bits = GetBits(v, 0, 2)
    if reserved == 1 then class = bits else rsv = bits end
  elseif group == 9 then
    -- Message with User Data Header (UDH) structure:
    class = GetBits(v, 0, 2)
    codec = CBC_DCS_CODEC[GetBits(v, 2, 2)]
    if not codec then return nil, ferror('reserved codec value: %.2X', v) end
  elseif group <= 12 then
    return nil, ferror('reserved coding groups: %.2X', v)
  elseif group == 13 then
    -- I1 protocol message defined in 3GPP TS 24.294
    return nil, ferror('unsupported: I1 protocol')
  elseif group == 14 then
    -- Defined by the WAP Forum [15]
    return nil, ferror('unsupported: WAP protocol')
  else
    local reserved = GetBits(v, 3)
    if reserved ~= 0 then return nil, ferror('invalid DCS byte: %.2X', v) end
    codec = GetBits(v, 2) == 0 and 'BIT7' or 'BIT8'
    class = GetBits(v, 0, 2)
  end

  local lang_code
  if lang then
    local t = LANG[group]
    if t then lang_code = t[lang] end
  end

  return{
    lang       = lang;
    lang_code  = lang_code;
    group      = group;
    class      = class;
    codec      = codec;
    compressed = compressed;
    reserved   = rsv;
  }
end

local CBC_DCS_CODEC = { ['BIT7'] = 0, ['BIT8'] = 4, ['UCS2'] = 8 }
local function DCSBroadcastEncode(t)
  local group = t.group

  if not group then
    if t.codec or t.class then group = 15 else group = 0 end
  end

  local v = bit.band(0xF0, bit.lshift(group, 4))

  if group == 1 then
    local codec
    if (not t.codec) or (t.codec == 'BIT7') then
      codec = 0
    elseif t.codec == 'UCS2' then
      codec = 1
    else
      return nil, ferror('unknown codec: %s', tostring(t.codec))
    end
    v = bit.bor(v, bit.band(0x0F, codec))
  elseif group <= 3 then
    local lang = t.lang
    if (not lang) and t.lang_code then
      local l = LANG_INVERT[group]
      if t then lang = l[t.lang_code] end
    end
    if t.codec and t.codec ~= 'BIT7' then
      return nil, ferror('invalid codec value %s for group %d', tostring(t.codec), group)
    end
    v = bit.bor(v, bit.band(0x0F, lang or 0x0F))
  elseif group <= 7 then -- 01xx xxxx
    local compressed = (t.compressed == true or t.compressed == 1) and 0x20 or 0x00
    local codec = CBC_DCS_CODEC[t.codec or 'BIT7']
    if not codec then return nil, ferror('unknown codec value: %s', tostring(t.codec)) end
    v = bit.bor(v, compressed, codec)
    if t.class or t.reserved then v = bit.bor(v, bit.band(0x03, t.class or t.reserved)) end
  elseif group == 9 then
    local codec = CBC_DCS_CODEC[t.codec or 'BIT7']
    if not codec then return nil, ferror('unknown codec value: %s', tostring(t.codec)) end
    v = bit.bor(v, codec)
    if t.class then v = bit.bor(v, bit.band(0x03, t.class)) end
  elseif group <= 14 then
    return nil, ferror('reserved coding groups: %.2X', v)
  else
    if t.codec then
      if t.codec == 'BIT8' then v = bit.bor(v, 0x04)
      elseif t.codec ~= 'BIT7' then
        return nil, ferror('Invalid codec: %s', tostring(t.codec))
      end
    end
    if t.class then v = bit.bor(v, bit.band(0x03, t.class)) end
  end

  return v
end

local function TSDecode(iter)
  local Y  = BcdDecode(iter:read_char(2))
  local M  = BcdDecode(iter:read_char(2))
  local D  = BcdDecode(iter:read_char(2))
  local h  = BcdDecode(iter:read_char(2))
  local m  = BcdDecode(iter:read_char(2))
  local s  = BcdDecode(iter:read_char(2))
  local tz = BcdDecode(iter:read_char(2))

  tz = tonumber(tz, 16)
  local sign_tz = bit.band(tz, 0x80) == 0
  tz = bit.band(tz, 0x7F)
  tz = tonumber(string.format('%.2X', tz))
  if tz then
    tz = tz / 4
    if not sign_tz then tz = -tz end
  end

  return {
    year  = tonumber(Y);
    month = tonumber(M);
    day   = tonumber(D);
    hour  = tonumber(h);
    min   = tonumber(m);
    sec   = tonumber(s);
    tz    = tz;
  }
end

local function TSEncode(ts)
  local tz = math.floor(math.abs(ts.tz) * 4)
  tz = string.format("%.2d", tz)

  if ts.tz < 0 then
    tz = tonumber(tz, 16)
    tz = bit.bor(tz, 0x80)
    tz = string.format("%.2X", tz)
  end

  return BcdEncode(
    string.format("%.2d%.2d%.2d%.2d%.2d%.2d%s",
      ts.year, ts.month, ts.day,
      ts.hour, ts.min, ts.sec, tz
    )
  )
end

local function VPDecode(iter, pdu)
  if not pdu.vpf or pdu.vpf == 0 then
    return
  end

  if pdu.vpf == 2 then -- relevant
    local v = iter:read_byte()
    if v <= 143 then
      v = (v + 1) * 5
    else
      if v <= 167 then
        v = (12*60) + (v - 143) * 30
      elseif v <= 196 then
        v = (v - 166) * (24 * 60)
      else
        v = (v - 192) * (7 * 24 * 60)
      end
    end
    return v
  end

  if pdu.vpf == 3 then -- absolute
    return TSDecode(iter)
  end

  return nil, ferror('invalid VP format: %.2d', pdu.vpf)
end

local function VPEncode(v, pdu)
  if not v then return '' end

  if type(v) == 'number' then -- relevant (pdu.vpf == 2)
    if v <= (12*60) then
      v = math.ceil(v / 5) - 1
    else
      if v <= (24 * 60) then
         v = math.ceil(v - (12*60), 30) + 143
      elseif v <= (30 * 24 * 60) then
        v = math.ceil(v / (24 * 60))
        v = v + 166
      else
        v = math.ceil(v / (7 * 24 * 60))
        v = v + 192
      end
    end
    return string.format("%.2X", v)
  end

  -- absolute (pdu.vpf == 3)
  return TSEncode(v)
end

local IE_Decode = {
  [0x00] = function(iter)
    local len = iter:read_byte()
    assert(len == 3)
    local ied = iter:peek_char(len*2)
    local ref = iter:read_byte()
    local cnt = iter:read_byte()
    local no  = iter:read_byte()
    return { iei = 0, ied = hex2bin(ied), cnt = cnt, ref = ref, no = no }
  end;

  [0x08] = function(iter)
    local len = iter:read_byte()
    assert(len == 4)
    local ied  = iter:peek_char(len*2)
    local ref1 = iter:read_byte()
    local ref2 = iter:read_byte()
    local cnt  = iter:read_byte()
    local no   = iter:read_byte()
    return { iei = 8, ied = hex2bin(ied), cnt = cnt, ref = bit.lshift(ref1,8) + ref2, no = no}
  end;
}

local IE_Encode = {
  [0x00] = function(t)
    if t.ref and t.cnt and t.no then
      return string.format("%.2X%.2X%.2X%.2X%.2X",
        0x00, 0x03, t.ref, t.cnt, t.no
      )
    end
  end;

  [0x08] = function(t)
    if t.ref and t.cnt and t.no then
      local ref1 = bit.band(0xFF, bit.rshift(t.ref, 8))
      local ref2 = bit.band(0xFF, t.ref)
      return string.format("%.2X%.2X%.2X%.2X%.2X%.2X",
        0x08, 0x04, ref1, ref2, t.cnt, t.no
      )
    end
  end;
}

local function UDHDecode(data)
  local iter = Iter.new(data)
  local res = {}
  while true do
    local iei  = iter:read_byte()
    if not iei then break end
    local decode = IE_Decode[iei]
    if decode then
      res[#res + 1] = decode(iter)
    else
      local iedl = iter:read_byte()
      res[#res + 1] = {
        iei = iei;
        ied = iter:read_str(iedl)
      }
    end
  end
  return res
end

local function UDHEncode(udh)
  local r = ''

  if type(udh) == 'table' then
    for _, t in ipairs(udh) do
      local enc = IE_Encode[t.iei]
      if enc then enc = enc(t) end
      if not enc then
        enc = string.format(
          '%.2X%.2X%s',
          t.iei, #t.ied, bin2hex(t.ied)
        )
      end
      r = r .. enc
    end
  else
    r = bin2hex(udh)
  end

  return string.format("%.2X%s",
    bit.rshift(#r, 1), r
  )
end

local function UDDecode(iter, pdu, dcs)
  local len = iter:read_byte()
  local udh, udhl

  if pdu.udhi then
    udhl = iter:read_byte()
    udh  = iter:read_char(udhl * 2)
    udh  = UDHDecode(udh)
  end

  local data
  if (not dcs) or (not dcs.codec) or (dcs.codec == 'BIT7') then
    local bytes, align = math.ceil(len * 7 / 8)
    if udhl then
      bytes = bytes - udhl
      align = 7 - (udhl + 1) % 7
      len   = len - math.ceil((udhl + 1) * 8 / 7)
    end

    data = iter:read_char(bytes * 2)
    data = Bit7Decode(hex2bin(data), align)
  else
    if udhl then len = len - udhl end
    data = iter:read_char(len * 2)
    data = hex2bin(data)
  end

  data = data:sub(1, len)
  return data, udh
end

local function UDEncode(msg, pdu, dcs)
  local udh, udhl
  if pdu.udh then
    udh = UDHEncode(pdu.udh)
    udhl = bit.rshift(#udh, 1)
  end

  local len, data
  if (not dcs) or (not dcs.codec) or (dcs.codec == 'BIT7') then
    local align
    if udh then align = 7 - udhl % 7 end
    data, len = Bit7Encode(msg, nil, align)
    if udh then len = len + (udhl * 8 + align) / 7 end
  else
    data, len = msg, #msg
    if udh then len = len + udhl end
  end

  return string.format("%.2X", len) .. (udh or '') .. bin2hex(data)
end

---
-- SUBMIT
-- SCA PDU-Type(MTI,RD,VPF,SRR,UDHI,RP) MR DA PID DCS VP UDL UD
--
-- DELIVER
-- SCA PDU-Type(MTI,MMS,SRI,UDHI,RP) OA PID DCS SCTS UDL UD
--
-- STATUS
-- SCA PDU-Type(MTI,MMS,SRQ) MR DA SCTS DTS TPS
--
-- DELIVER-REPORT (ERROR)
-- SCA PDU-Type(MTI) FCS
--
-- DELIVER-REPORT (ACK)
-- SCA PDU-Type(MTI) PI PID DCS UDL UD
--
-- SUBMIT-REPORT (ERROR)
-- SCA PDU-Type(MTI) FCS
--
-- SUBMIT-REPORT (ACK)
-- SCA PDU-Type(MTI) PI SCTS PID DCS UDL UD
--

local function PDUDecoder(pdu, direct, len)

  if pdu:find("%X") then
    return nil, ferror('invalid PDU format')
  end

  local iter = Iter.new(pdu)
  if iter:rest() % 2 ~= 0 then
    return nil, ferror('invalid PDU length')
  end

  local sca, err  = SCADecode(iter)
  if not sca then return nil, err end

  if len and (len * 2) ~= iter:rest() then
    return nil, ferror('invalid PDU length')
  end

  local tp, err   = PDUTypeDecode(iter, direct)
  if not tp then return nil, err end

  local mr
  if tp.mti == 'SUBMIT' or tp.mti == 'STATUS' then
    mr = iter:read_byte()
    if not mr then return nil, ferror('invalid PDU length') end
  end

  local addr, err = AddressDecode(iter)
  if not addr then return nil, err end

  local pid
  if tp.mti == 'SUBMIT' or tp.mti == 'DELIVER' then
    pid = iter:read_byte()
    if not pid then return nil, ferror('invalid PDU length') end
  end

  local dcs
  if tp.mti == 'SUBMIT' or tp.mti == 'DELIVER' then
    dcs, err = DCSDecode(iter)
    if not dcs then return nil, err end
  end

  local scts
  if tp.mti == 'STATUS' or tp.mti == 'DELIVER' then
    scts, err = TSDecode(iter)
    if not scts then return nil, err end
  end

  local dts
  if tp.mti == 'STATUS' then
    dts, err = TSDecode(iter)
    if not dts then return nil, err end
  end

  local status
  if tp.mti == 'STATUS' then
    status = iter:read_byte()
    if not status then return nil, ferror('invalid PDU length') end
    status = STInfo(status)
  end

  local vp
  if tp.mti == 'SUBMIT' then
    vp, err = VPDecode(iter, tp)
    if not vp and err then return nil, err end
  end

  local ud, udh
  if tp.mti == 'SUBMIT' or tp.mti == 'DELIVER' then
    ud, udh = UDDecode(iter, tp, dcs)
    if not ud then return nil, udh end
  end

  local msg = {
    sc     = sca;
    tp     = tp;
    addr   = addr;
    mr     = mr;
    pid    = pid;
    dcs    = dcs;
    scts   = scts;
    dts    = dts;
    status = status;
    vp     = vp;
    ud     = ud;
    udh    = udh;
  }

  return msg
end

local function PDUEncoder(msg)
  local res = {}

  local tp  = msg.tp  or {mti = 'SUBMIT'}
  local sc  = msg.sc
  local dcs = msg.dcs or {}
  local mti = tp.mti or 'SUBMIT'

  res[#res + 1] = SCAEncode(sc)
  local sc_len  = #res[#res]

  res[#res + 1] = PDUTypeEncode(tp, msg)

  if mti == 'SUBMIT' or mti == 'STATUS' then
    res[#res + 1] = string.format("%.2X", msg.mr or 0)
  end

  res[#res + 1] = AddressEncode(msg.addr)

  if mti == 'SUBMIT' or mti == 'DELIVER' then
    res[#res + 1] = string.format("%.2X", msg.pid or 0)
  end

  if mti == 'SUBMIT' or mti == 'DELIVER' then
    res[#res + 1] = DCSEncode(dcs)
  end

  if mti == 'STATUS' or mti == 'DELIVER' then
    res[#res + 1] = TSEncode(msg.scts)
  end

  if mti == 'SUBMIT' then
     res[#res + 1] = VPEncode(msg.vp, tp)
  end

  if mti == 'STATUS' then
    res[#res + 1] = TSEncode(msg.dts)
  end

  if mti == 'STATUS' then
    local status = msg.status
    if type(status) == 'table' then
      status = status.status
    end
    res[#res + 1] = string.format("%.2X", status or 0)
  end

  if mti == 'SUBMIT' or mti == 'DELIVER' then
    res[#res + 1] = UDEncode(msg.ud, msg, msg.dcs)
  end

  local pdu = table.concat(res)
  local len = #pdu - sc_len
  return pdu, math.floor(len/2 + 0.5)
end

return {
  _NAME      = "tpdu";
  _VERSION   = "0.1.0";
  _COPYRIGHT = "Copyright (C) 2015-2016 Alexey Melnichuk";
  _LICENSE   = "MIT";

  Encode = PDUEncoder;
  Decode = PDUDecoder;

  _Iter     = Iter;
  _TSDecode = TSDecode;
  _TSEncode = TSEncode;

  _DCSBroadcastDecode = DCSBroadcastDecode;
  _DCSBroadcastEncode = DCSBroadcastEncode;

  _DecodeStatus = STInfo;
}
