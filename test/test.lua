-- package.path = "..\\src\\lua\\?.lua;" .. package.path

pcall(require, "luacov")

local tpdu           = require "tpdu"
local Bit7           = require "tpdu.bit7"
local Bcd             = require "tpdu.bcd"
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
    local enc = assert_string(Bit7.GsmEncode(data[1]))
    local dec = assert_string(Bit7.GsmDecode(ut.hex2bin(data[3])))
    enc = ut.bin2hex(enc)

    assert_equal(data[2], dec)
    assert_equal(data[3], enc)
  end)
end

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

end


RUN()