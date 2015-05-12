-- package.path = "..\\src\\lua\\?.lua;" .. package.path

pcall(require, "luacov")

local tpdu           = require "tpdu"
local Bit7           = require "tpdu.bit7"
local Bcd            = require "tpdu.bcd"
local ut             = require "tpdu.utils"

local utils          = require "utils"
local TEST_CASE      = require "lunit".TEST_CASE

local pcall, error, type, table, ipairs, tostring = pcall, error, type, table, ipairs, tostring
local RUN = utils.RUN
local IT, CMD, PASS = utils.IT, utils.CMD, utils.PASS
local nreturn, is_equal = utils.nreturn, utils.is_equal

local ENABLE = true

local _ENV = TEST_CASE'7bit encoding' if ENABLE then

local it = IT(_ENV or _M)

local EncodeTest = {
  {"hello[world]! \191?", "hello[world]! ??",   "E8329BFDDEF0EE6F399BBCF18540BF1F"},
  {"AAAAAAAAAAAAAAB\r",   "AAAAAAAAAAAAAAB\r",  "C16030180C0683C16030180C0A1B0D"  },
  {"AAAAAAAAAAAAAAB",     "AAAAAAAAAAAAAAB",    "C16030180C0683C16030180C0A1B"    },
  {"height of eifel",     "height of eifel",    "E872FA8CA683DE6650396D2EB31B"    },
}

for i, data in ipairs(EncodeTest) do
  it("Test #" .. tostring(i), function()
    local enc = assert_string(Bit7.GsmEncode(data[1], true))
    local dec = assert_string(Bit7.GsmDecode(ut.hex2bin(data[3])))
    enc = ut.bin2hex(enc)

    assert_equal(data[2], dec)
    assert_equal(data[3], enc)
  end)
end

it("Test encode align #1", function()
  local msg = 'Hello world'
  local enc = '906536FB0DBABFE56C32'
  assert_equal(enc, ut.bin2hex(Bit7.GsmEncode(msg, nil, 1)))
end)

it("Test decode align #1", function()
  local msg = 'Hello world'
  local enc = '906536FB0DBABFE56C32'
  assert_equal(msg, Bit7.GsmDecode(ut.hex2bin(enc), 1))
end)

it("Test encode align #1 with padding", function()
  local msg = 'Hello wo'
  local enc = '906536FB0DBABF1B'
  assert_equal(enc, ut.bin2hex(Bit7.GsmEncode(msg, true, 1)))
end)

it("Test encode align #1 without padding", function()
  local msg = 'Hello wo'
  local enc = '906536FB0DBABF01'
  assert_equal(enc, ut.bin2hex(Bit7.GsmEncode(msg, false, 1)))
end)

end

local _ENV = TEST_CASE'BCD encoding' if ENABLE then

local it = IT(_ENV or _M)

it('should encode', function()
  local str = "123456"
  assert_equal('214365', Bcd.Encode(str))
end)

it('should encode and pad', function()
  local str = "12345"
  assert_equal('2143F5', Bcd.Encode(str))
end)

it('should decode', function()
  local str = "123456"
  assert_equal('214365', Bcd.Decode(str))
end)

it('should fail decode', function()
  local str = "12345"
  assert_nil(Bcd.Decode(str))
end)

it('should decode pad', function()
  local str = "2143F5"
  assert_equal('12345F', Bcd.Decode(str))
end)

end

local _ENV = TEST_CASE'Circle tests' if ENABLE then

local it = IT(_ENV or _M)

it('SMS-DELIVER', function()
  local pdu = '0791448720003023240DD0E474D81C0EBB010000111011315214000BE474D81C0EBB5DE3771B'
  local ms = tpdu.Decode(pdu, 'input')
  assert_equal(pdu, tpdu.Encode(ms))
end)

it('SMS-STATUS-REPORT', function()
  local pdu = '0006D60B911326880736F4111011719551401110117195714000'
  local ms = tpdu.Decode(pdu, 'input')
  assert_equal(pdu, tpdu.Encode(ms))
end)

it('SMS-SUBMIT 7bit', function()
  local pdu = '04912143F501000B811000000000F0000030C834888E2ECBCB2E97ABF9768364303A1A1484CB413258AC068AC574B39A6B560385DB20D4B1495DC552'
  local ms = tpdu.Decode(pdu)
  assert_equal(pdu, tpdu.Encode(ms))
end)

it('SMS-SUBMIT UCS2', function()
  local pdu = '039121F33100039121F30018BC0C041F04400438043204350442'
  local ms = tpdu.Decode(pdu)
  assert_equal(pdu, tpdu.Encode(ms))
end)

it('SMS-SUBMIT 7bit udh', function()
  local pdu = '0041000691214365000012050003CC0201906536FB0DBABFE56C32'
  local ms = tpdu.Decode(pdu)
  assert_equal(pdu, tpdu.Encode(ms))
end)

it('SMS-DELIVER unknown udh', function()
  local pdu = '0791539111161616640C9153916161755000F54020310164450084831281000615FFFFE7F6E003E193CC0B0000E793D1460000E193D2A00000E793D1400000E1C7D0900000FFFFD2A00000F88FD1400000F047E8806003F007F700D3E6F82C79D06413FC5C7EE809C8FE3FFF7012E4FFFFFFA823E2E0867FB021C2F99E7FA8208289867FB42082899FFF9A2492F9867FDD13E4FFFFFFEE8808FFFFFFED4808'
  local ms = tpdu.Decode(pdu, 'input')
  assert_equal(pdu, tpdu.Encode(ms))
end)

end

local _ENV = TEST_CASE'Timestamp tests' if ENABLE then

local it = IT(_ENV or _M)

local tests = {
  {'9001425100704A', {
    year=09, month=10, day=24,
    hour=15, min  =00, sec=07,
    tz=-6,
  }},
  {'21204141336202', {
    year=12, month=02, day=14,
    hour=14, min  =33, sec=26,
    tz=5,
  }},
  {'11119190046422', {
    year=11, month=11, day=19,
    hour=09, min  =40, sec=46,
    tz=5.5,
  }},
}

for i, t in ipairs(tests) do
  it(("test decode #%d"):format(i), function()
    local iter = tpdu._Iter.new(t[1])
    local et = t[2]
    local ts = assert_table(tpdu._TSDecode(iter))
    assert_equal(et.year  , ts.year  )
    assert_equal(et.month , ts.month )
    assert_equal(et.day   , ts.day   )
    assert_equal(et.hour  , ts.hour  )
    assert_equal(et.min   , ts.min   )
    assert_equal(et.sec   , ts.sec   )
    assert_equal(et.tz    , ts.tz    )
  end)

  it(("test encode #%d"):format(i), function()
    local et = tpdu._TSEncode(t[2])
    assert(t[1] == et)
  end)

end

end

local _ENV = TEST_CASE'Long SMS' if ENABLE then

local it = IT(_ENV or _M)

it('should decode 7bit with align', function()
  local str = '0041000691214365000012050003CC0201906536FB0DBABFE56C32'
  local pdu = assert_table(tpdu.Decode(str))
  assert_equal('Hello world', pdu.ud)
  assert_true(pdu.tp.udhi)
  assert_table(pdu.udh)
  local ie = assert_table(pdu.udh[1])
  assert_equal(0x00, ie.iei)
  assert_equal(0x02, ie.cnt)
  assert_equal(0x01, ie.no)
  assert_equal(0xCC, ie.ref)
end)

end

local _ENV = TEST_CASE'Encode SMS' if ENABLE then

local it = IT(_ENV or _M)

it('should deduce vp and udhi flags', function()
  local pdu = {
    ud   = 'Hello world',
    addr = '+123456',
    udh  = {
      {iei=0, cnt=2, no=1, ref=204}
    },
    vp   = 10080,
  }
  local enc = '00510006912143650000AD12050003CC0201906536FB0DBABFE56C32'
  assert_equal(enc, tpdu.Encode(pdu, 'output'))
end)

end

RUN()
