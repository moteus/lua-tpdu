local math   = require 'math'
local string = require 'string'

local function BcdEncode(str)
  if #str % 2 == 1 then
    str = str .. 'F'
  end

  str = str:gsub('(.)(.)', function(a, b) return b .. a end)
  return str
end

local function BcdDecode(str)
  if #str % 2 == 1 then
    return nil, 'string lenght not even'
  end

  str = str:gsub('(.)(.)', function(a, b) return b .. a end)
  return str
end

return {
  Encode = BcdEncode;
  Decode = BcdDecode;
}