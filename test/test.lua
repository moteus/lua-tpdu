-- package.path = "..\\src\\lua\\?.lua;" .. package.path

pcall(require, "luacov")

local tpdu           = require "tpdu"
local Bit7           = require "tpdu.bit7"
local Bcd            = require "tpdu.bcd"
local ut             = require "tpdu.utils"

print("------------------------------------")
print("Module    name: " .. tpdu._NAME);
print("Module version: " .. tpdu._VERSION);
print("Lua    version: " .. (_G.jit and _G.jit.version or _G._VERSION))
print("------------------------------------")
print("")

local utils          = require "utils"
local TEST_CASE      = require "lunit".TEST_CASE

local pcall, error, type, table, ipairs, tostring = pcall, error, type, table, ipairs, tostring
local RUN = utils.RUN
local IT, CMD, PASS = utils.IT, utils.CMD, utils.PASS
local nreturn, is_equal = utils.nreturn, utils.is_equal

local function b(s)
  return tonumber(s:gsub('[^01]', ''), 2)
end

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

local tests = {
  { 'SMS-DELIVER',
    '0791448720003023240DD0E474D81C0EBB010000111011315214000BE474D81C0EBB5DE3771B',
    'input'
  };
  { 'SMS-STATUS-REPORT',
    '0006D60B911326880736F4111011719551401110117195714000',
    'input'
  };
  { 'SMS-SUBMIT 7bit',
    '04912143F501000B811000000000F0000030C834888E2ECBCB2E97ABF9768364303A1A1484CB413258AC068AC574B39A6B560385DB20D4B1495DC552',
    'output'
  };
  { 'SMS-DELIVER 7bit Addr 8 chars',
    '0791448720003023240ED0C6E0B0287C3E970000111011315214000BE474D81C0EBB5DE3771B',
    'input'
  };
  { 'SMS-SUBMIT UCS2',
    '039121F33100039121F30018BC0C041F04400438043204350442',
    'output'
  };
  { 'SMS-SUBMIT 7bit udh',
    '0041000691214365000012050003CC0201906536FB0DBABFE56C32',
    'output'
  };
  { 'SMS-DELIVER unknown udh',
    '0791539111161616640C9153916161755000F54020310164450084831281000615FFFFE7F6E003E193CC0B0000E793D1460000E193D2A00000E793D1400000E1C7D0900000FFFFD2A00000F88FD1400000F047E8806003F007F700D3E6F82C79D06413FC5C7EE809C8FE3FFF7012E4FFFFFFA823E2E0867FB021C2F99E7FA8208289867FB42082899FFF9A2492F9867FDD13E4FFFFFFEE8808FFFFFFED4808',
    'input'
  };
  { 'SMS-SUBMIT with alphanumeric numbers',
    '0BD0CDFCB43D1F3BDBE2B21C01000DD0CDBCB32D2ECB0100000BC8329BFD06DDDF723619',
    'output'
  };
  { 'SMS-SUBMIT with udh concat 8bit',
    '00410006A1214365000012050003170301906536FB0DBABFE56C32',
    'output'
  };
  { 'SMS-SUBMIT with udh concat 16bit',
    '00410006A121436500001406080401800402C8329BFD06DDDF723619',
    'output'
  };
  { 'SMS-SUBMIT with udh gsm7',
    '00610009A119995559F600009F050003010B0162B219AD668BC966B49A2D269BD16AB6986C46ABD962B219AD668BC966B49A2D269BD16AB6986C46ABD962B219AD668BC966B49A2D269BD16AB6986C46ABD962B219AD668BC966B49A2D269BD16AB6986C46ABD962B219AD668BC966B49A2D269BD16AB6986C46ABD962B219AD668BC966B49A2D269BD16AB6986C46ABD962B219AD668BC900',
    'output'
  };
}

for _, T in ipairs(tests) do
local name, pdu, direct = T[1], T[2], T[3]

it(name, function()
  local msg = assert_table(tpdu.Decode(pdu, direct))
  assert_equal(pdu, tpdu.Encode(msg))
end)

end

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

it('should encode alphanumeric numbers', function()
  local pdu = {
    sc   = {
      number = 'MySmscNmber',
      npi   = 'UNKNOWN', ton = 'ALPHANUMERIC'
    },
    addr = {
      number = 'MyNmber',
      npi   = 'UNKNOWN', ton = 'ALPHANUMERIC'
    },
    ud   = 'Hello world',
  }

  local enc = '0BD0CDFCB43D1F3BDBE2B21C01000DD0CDBCB32D2ECB0100000BC8329BFD06DDDF723619'
  assert_equal(enc, tpdu.Encode(pdu, 'output'))
end)

it('should encode udh concat 8bit', function()
  local pdu = {
    addr = '123456',
    ud   = 'Hello world',
    udh  = {
      {iei = 0, ref = 23, cnt = 3, no = 1}
    }
  }

  local enc = '00410006A1214365000012050003170301906536FB0DBABFE56C32'
  assert_equal(enc, tpdu.Encode(pdu, 'output'))
end)

it('should encode udh concat 16bit', function()
  local pdu = {
    addr = '123456',
    ud   = 'Hello world',
    udh  = {
      {iei = 8, ref = 384, cnt = 4, no = 2}
    }
  }

  local enc = '00410006A121436500001406080401800402C8329BFD06DDDF723619'
  assert_equal(enc, tpdu.Encode(pdu, 'output'))
end)

end

local _ENV = TEST_CASE'DCS Broadcast encode' if ENABLE then

local it = IT(_ENV or _M)

it('circle', function()
  for i = 0, 255 do
    local t = tpdu._DCSBroadcastDecode(i)
    if t then
      assert_equal(i, tpdu._DCSBroadcastEncode(t))
    end
  end
end)

it('should process groups 0000,0010,0011', function()
  local value = b'0000 1011'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 0,      t.group)
  assert_nil  (         t.class)
  assert_equal( 'EL',   t.lang_code)
  assert_equal(b'1011', t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_nil  (         t.compressed)

  -- Support encode using language code
  assert_equal(value, tpdu._DCSBroadcastEncode{group = 0; codec = 'BIT7'; lang_code = 'EL'})

  local value = b'0010 0011'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 2,      t.group)
  assert_nil  (         t.class)
  assert_equal( 'RU',   t.lang_code)
  assert_equal(b'0011', t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_nil  (         t.compressed)

  -- Support encode using language code
  assert_equal(value, tpdu._DCSBroadcastEncode{group = 2; lang_code = 'RU'})

  -- Reserved language
  local value = b'0000 1111'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 0,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_equal(b'1111', t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_nil  (         t.compressed)

  -- Support only BIT7
  assert_nil(tpdu._DCSBroadcastEncode{group = 0; codec = 'UCS2'})
end)

it('should process group 0001', function()
  local value = b'0001 0000'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 1,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_nil  (         t.compressed)

  local value = b'0001 0001'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 1,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'UCS2', t.codec)
  assert_nil  (         t.compressed)

  -- Unsopported codec
  assert_nil(tpdu._DCSBroadcastEncode{group = 1; codec = 'BIT8'})
end)

it('should process group 01XX', function()
  local value = b'0100 0000'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 4,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_false(         t.compressed)

  local value = b'0100 0100'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 4,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT8', t.codec)
  assert_false(         t.compressed)

  local value = b'0100 1000'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 4,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'UCS2', t.codec)
  assert_false(         t.compressed)

  -- Reserved codec value
  local value = b'0100 1100'
  assert_nil(tpdu._DCSBroadcastDecode(value))

  local value = b'0101 0000'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 5,      t.group)
  assert_equal( 0,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_false(         t.compressed)

  local value = b'0101 0001'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 5,      t.group)
  assert_equal( 1,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_false(         t.compressed)

  local value = b'0101 0010'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 5,      t.group)
  assert_equal( 2,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_false(         t.compressed)

  local value = b'0101 0011'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 5,      t.group)
  assert_equal( 3,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_false(         t.compressed)

  local value = b'0110 0000'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 6,      t.group)
  assert_nil  (         t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_true (         t.compressed)
end)

it('should process group 1001', function()
  local value = b'1001 0110'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 9,      t.group)
  assert_equal( 2,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT8', t.codec)
  assert_nil  (         t.compressed)
end)

it('should process group 1111', function()
  local value = b'1111 0000'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 15,     t.group)
  assert_equal( 0,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_nil  (         t.compressed)

  -- Reserved bit
  local value = b'1111 1000'
  assert_nil(tpdu._DCSBroadcastDecode(value))

  local value = b'1111 0011'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 15,     t.group)
  assert_equal( 3,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT7', t.codec)
  assert_nil  (         t.compressed)

  local value = b'1111 0110'
  local t = assert(tpdu._DCSBroadcastDecode(value))
  assert_equal( 15,     t.group)
  assert_equal( 2,      t.class)
  assert_nil  (         t.lang_code)
  assert_nil  (         t.lang)
  assert_equal( 'BIT8', t.codec)
  assert_nil  (         t.compressed)
end)

it('should process reserved groups', function()
  assert_nil(tpdu._DCSBroadcastDecode(b'1000 0000'))
  assert_nil(tpdu._DCSBroadcastDecode(b'1010 0000'))
  assert_nil(tpdu._DCSBroadcastDecode(b'1011 0000'))
  assert_nil(tpdu._DCSBroadcastDecode(b'1101 0000'))
  assert_nil(tpdu._DCSBroadcastDecode(b'1110 0000'))
end)

end

local _ENV = TEST_CASE'Check PDU format' if ENABLE then

local it = IT(_ENV or _M)

it('SMS-DELIVER Pass', function()
  local pdu = '07919761989901F0040B917777777777F70000515022114032210A31D98C56B3DD703918'
  local ms = assert_table(tpdu.Decode(pdu, 'input', 28))
end)

it('SMS-DELIVER Not even', function()
  local pdu = '07919761989901F0040B917777777777F70000515022114032210A31D98C56B3DD70391'
  local ms = assert_nil(tpdu.Decode(pdu, 'input', 28))
end)

it('SMS-DELIVER Too long', function()
  local pdu = '07919761989901F0040B917777777777F70000515022114032210A31D98C56B3DD70391888'
  local ms = assert_nil(tpdu.Decode(pdu, 'input', 28))
end)

it('Invalid charset', function()
  local pdu = '07919761989901F0040B917777777777F70000515022114032210A31D98C56B3DD70391X'
  local ms = assert_nil(tpdu.Decode(pdu, 'input', 28))
end)

it('Error object', function()
  local pdu = '07919761989901F0040B917777777777F70000515022114032210A31D98C56B3DD70391X'
  local ms, err = assert_nil(tpdu.Decode(pdu, 'input', 28))
  assert(err)
  assert_equal('TPDU', err:cat())
  assert_number(err:no())
  assert_string(err:name())
  assert_string(err:msg())
  assert_not_nil(tostring(err):find(err:msg(), nil, true))
  assert_not_nil(tostring(err):find('[TPDU]', nil, true))
end)

end

RUN()
