if #KEYS ~= 1 or #ARGV ~= 3 then
  return redis.error_reply("wrong number of arguments")
end

local prefix = KEYS[1]
local member = ARGV[1]
local min    = tonumber(ARGV[2])
local max    = tonumber(ARGV[3])

if min == nil or max == nil or min > max then
  return redis.error_reply("min/max are not numeric or out of range")
end

local index  = prefix .. ":~"
local window = redis.call('zrangebyscore', index, min, max)
local before = nil
local after  = nil
local minwrp = {}
local maxwrp = {}

-- Remove the member from all sets between min & max
for _, val in pairs(window) do
  redis.call('srem', prefix .. ":" .. val, member)
end

-- Identify members wrapped in min
before = redis.call('zrevrangebyscore', index, "(" .. min, "-inf", "limit", 0, 1)[1]
if before then
  after = redis.call('zrangebyscore', index, "(" .. min, "inf", "limit", 0, 1)[1]
  if after then
    minwrp = redis.call('sinter', prefix .. ":" .. before, prefix .. ":" .. after)
  end
end

-- Identify members wrapped in max
after = redis.call('zrangebyscore', index, "(" .. max, "inf", "limit", 0, 1)[1]
if after then
  before = redis.call('zrevrangebyscore', index, "(" .. max, "-inf", "limit", 0, 1)[1]
  if before then
    maxwrp = redis.call('sinter', prefix .. ":" .. before, prefix .. ":" .. after)
  end
end

-- Remove existing wrapped members from min
if #minwrp > 0 then
  redis.call('srem', prefix .. ":" .. min, unpack(minwrp))
end

-- Remove existing wrapped members from max
if #maxwrp > 0 then
  redis.call('srem', prefix .. ":" .. max, unpack(maxwrp))
end

-- Remove the min index, if no more items are left in the min set
local minlen = redis.call('scard', prefix .. ":" .. min)
if minlen == 0 then redis.call('zrem', index, min) end

-- Remove the max index, if no more items are left in the max set
local maxlen = redis.call('scard', prefix .. ":" .. max)
if maxlen == 0 then redis.call('zrem', index, max) end

return redis.status_reply("OK")