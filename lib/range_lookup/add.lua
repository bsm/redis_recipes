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
local minscr = redis.call('zscore', index, min)
local maxscr = redis.call('zscore', index, max)
local minwrp = {}
local maxwrp = {}
local window = redis.call('zrangebyscore', index, "(" .. min, "(" .. max)

-- Find existing members to be included in the new min
if not minscr then
  local before = redis.call('zrevrangebyscore', index, "(" .. min, "-inf", "limit", 0, 1)[1]
  if before then
    local after = redis.call('zrangebyscore', index, "(" .. min, "inf", "limit", 0, 1)[1]
    if after then
      minwrp  = redis.call('sinter', prefix .. ":" .. before, prefix .. ":" .. after)
    end
  end
end

-- Find existing members to be included in the new max
if not maxscr then
  local after = redis.call('zrangebyscore', index, "(" .. max, "inf", "limit", 0, 1)[1]
  if after then
    local before = redis.call('zrevrangebyscore', index, "(" .. max, "-inf", "limit", 0, 1)[1]
    if before then
      maxwrp  = redis.call('sinter', prefix .. ":" .. before, prefix .. ":" .. after)
    end
  end
end

-- Store members in min & max sets
redis.call('sadd', prefix .. ":" .. min, member)
redis.call('sadd', prefix .. ":" .. max, member)

-- Store new min & max indices
if not minscr then redis.call('zadd', index, min, min) end
if not maxscr then redis.call('zadd', index, max, max) end

-- Store member in all existing sets between min & max
for _,key in pairs(window) do
  redis.call('sadd', prefix .. ":" .. key, member)
end

-- Merge existing members into min
if #minwrp > 0 then
  redis.call('sadd', prefix .. ":" .. min, unpack(minwrp))
end

-- Merge existing members into max
if #maxwrp > 0 then
  redis.call('sadd', prefix .. ":" .. max, unpack(maxwrp))
end

return redis.status_reply("OK")