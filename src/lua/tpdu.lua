local utils = require "tpdu.utils"
local Bit7  = require "tpdu.bit7"
local Bcd   = require "tpdu.bcd"
local bit   = utils.bit

local Gsm7Encode, Gsm7Decode = Bit7.GsmEncode, Bit7.GsmDecode
local BcdDecode, BcdEncode = Bcd.Decode, Bcd.Encode

local hex2bin, bin2hex = utils.hex2bin, utils.bin2hex
local GetBits, SetBits = utils.GetBits, utils.SetBits

local Iter = utils.class() do

function Iter:__init(s)
  self._s = s
  self._i = 1
  return self
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
};

local NPI = { -- NUMBERINGPLANIDENTIFICATION
  UNKNOWN    = 0,
  ISDN       = 1,
  X121       = 3,
  TELEX      = 4,
  NATIONAL   = 8,
  PRIVATE    = 9,
  ERMES      = 10,
  RESERVED   = 15
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
  CLASS_3
};

local DCS_CODEC = {
  BIT7     = 0,
  BIT8     = 1,
  UCS2     = 2,
  RESERVED = 3
};

local DCS_GROUP = {
  DCS_GROUP_0,
  DCS_GROUP_6
};

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
    smsc.number = Gsm7Decode(smsc.number)
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

  local len = math.ceil(#number / 2) + 1
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

local function PDUTypeEncode(tp)
  local v = 0

  local mti = tp.mti or 'SUBMIT'
  local _, m = find(MTI, mti)

  v = SetBits(v, 0, m)

  if mti == 'SUBMIT' then
    v = SetBits(v, 2, tp.rd,   0)
    v = SetBits(v, 3, tp.vpf,  0)
    v = SetBits(v, 5, tp.srr,  0)
    v = SetBits(v, 6, tp.udhi, 0)
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
    local symbols = math.ceil(len * 4 / 8)
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
    number = bin2hex(Gsm7Encode(number, 0))
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
        group = 'DATA'
        local reserved = GetBits(v, 3) == 1
        assert(not reserved)
        codec = (GetBits(v, 2) == 0) and 'BIT7' or 'BIT8'
        class = GetBits(v, 0, 2)
      else
        if typ == 0 then
          group = 'DISCARD'
          codec = 'BIT7'
        elseif typ == 1 then
          group = 'STORE'
          codec = 'BIT7'
        elseif typ == 2 then
          group = 'STORE'
          codec = 'UCS2'
        end
        local reserved = GetBits(v, 2) == 1
        assert(not reserved)
        indication = 'NONE'
        if GetBits(v, 3) == 1 then
          indication = GetBits(v, 0, 2)
        end
      end
    else error('reserved') end
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
    if group == 'DATA' then
      v = 0xFF
      if codec == 'BIT8' then
        v = SetBits(v, 2, 1)
      end
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

local function TSDecode(iter)
  local Y  = BcdDecode(iter:read_char(2))
  local M  = BcdDecode(iter:read_char(2))
  local D  = BcdDecode(iter:read_char(2))
  local h  = BcdDecode(iter:read_char(2))
  local m  = BcdDecode(iter:read_char(2))
  local s  = BcdDecode(iter:read_char(2))
  local tz = BcdDecode(iter:read_char(2))

  return {
    year  = tonumber(Y);
    month = tonumber(M);
    day   = tonumber(D);
    hour  = tonumber(h);
    min   = tonumber(m);
    sec   = tonumber(s);
    tz    = tonumber(tz);
  }
end

local function TSEncode(ts)
  return BcdEncode(
    string.format("%.2d%.2d%.2d%.2d%.2d%.2d%.2d",
      ts.year, ts.month, ts.day,
      ts.hour, ts.min, ts.sec, ts.tz
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

  error('Reserved format')
end

local function VPEncode(v, pdu)
  if not pdu.vpf or pdu.vpf == 0 then
    return ''
  end

  if pdu.vpf == 2 then -- relevant
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

  if pdu.vpf == 3 then -- absolute
    return TSEncode(v)
  end

  error('Reserved format')
end

local IE_Decode = {
  [0] = function(iter)
    local len = iter:read_byte()
    assert(len == 3)
    local ref = iter:read_byte()
    local cnt = iter:read_byte()
    local no  = iter:read_byte()
    return { iei = 0, cnt = cnt, ref = ref, no = no }
  end;

  [8] = function(iter)
    local len = iter:read_byte()
    assert(len == 4)
    local ref1 = iter:read_byte()
    local ref2 = iter:read_byte()
    local cnt = iter:read_byte()
    local no  = iter:read_byte()
    return { iei = 8, cnt = cnt, ref = bit.lshift(ref1,8) + ref2, no = no}
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

local function UDHEncode(udh, dcs)
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
    local bytes = math.ceil(len * 7 / 8)
    if udhl then bytes = bytes - udhl end
    data = iter:read_char(bytes * 2)
    data = Gsm7Decode(hex2bin(data))
  else
    if udhl then len = len - udhl end
    data = iter:read_char(len * 2)
    data = hex2bin(data)
  end

  return data, udh
end

local function UDEncode(msg, dcs)
  local len, data
  if (not dcs) or (not dcs.codec) or (dcs.codec == 'BIT7') then
    data, len = Gsm7Encode(msg, 0)
  else
    data, len = msg, #msg
  end

  return string.format("%.2X", len) .. bin2hex(data)
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

local function PDUDecoder(pdu, direct)
  local iter = Iter.new(pdu)
  local sca  = SCADecode(iter)
  local tp   = PDUTypeDecode(iter, direct)

  local mr
  if tp.mti == 'SUBMIT' or tp.mti == 'STATUS' then
    mr = iter:read_byte()
  end

  local addr = AddressDecode(iter)

  local pid
  if tp.mti == 'SUBMIT' or tp.mti == 'DELIVER' then
    pid = iter:read_byte()
  end

  local dcs
  if tp.mti == 'SUBMIT' or tp.mti == 'DELIVER' then
    dcs = DCSDecode(iter)
  end

  local scts
  if tp.mti == 'STATUS' or tp.mti == 'DELIVER' then
    scts = TSDecode(iter)
  end

  local dts
  if tp.mti == 'STATUS' then
    dts = TSDecode(iter)
  end

  local status
  if tp.mti == 'STATUS' then
    status = iter:read_byte()
    status = STInfo(status)
  end

  local vp
  if tp.mti == 'SUBMIT' then
    vp = VPDecode(iter, tp)
  end

  local ud, udh
  if tp.mti == 'SUBMIT' or tp.mti == 'DELIVER' then
    ud, udh = UDDecode(iter, tp, dcs)
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

  res[#res + 1] = PDUTypeEncode(tp)

  if mti == 'SUBMIT' or mti == 'STATUS' then
    res[#res + 1] = string.format("%.2X", msg.mr or 0)
  end

  res[#res + 1] = AddressEncode(msg.addr)

  if mti == 'SUBMIT' or mti == 'DELIVER' then
    res[#res + 1] = string.format("%.2X", msg.pid or 0)
  end

  if mti == 'SUBMIT' or mti == 'DELIVER' then
    res[#res + 1] = DCSEncode(msg.dcs)
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
    res[#res + 1] = UDEncode(msg.ud, msg.dcs)
  end

  local pdu = table.concat(res)
  local len = #pdu - sc_len
  return pdu, math.floor(len/2 + 0.5)
end

return {
  Encode = PDUEncoder;
  Decode = PDUDecoder;
}
