if #KEYS ~= 1 or #ARGV ~= 3 then
  return redis.error_reply("wrong number of arguments")
end

local prefix = KEYS[1]
local member = ARGV[1]
local min    = tonumber(ARGV[2])
local max    = tonumber(ARGV[3])

if min == nil or max == nil or min >= max then
  return redis.error_reply("min/max are not numeric or out of range")
end

local index   = prefix .. ":~"
local window  = redis.call('zrangebyscore', index, min, "(" .. max)

local minlen  = redis.call('scard', prefix .. ":" .. min)
local maxlen  = redis.call('scard', prefix .. ":" .. max)

-- Calculate cardinality of the set before min
local befmin  = redis.call('zrevrangebyscore', index, "(" .. min, "-inf", "limit", 0, 1)[1]
local bminlen = 0
if befmin then
  bminlen = redis.call('scard', prefix .. ":" .. befmin)
end

-- Calculate cardinality of the set before max
local befmax  = redis.call('zrevrangebyscore', index, "(" .. max, "-inf", "limit", 0, 1)[1]
local bmaxlen = 0
if befmax then
  bmaxlen = redis.call('scard', prefix .. ":" .. befmax)
end

-- Remove min if the cardinality between min and the set before min differs by 1
if minlen - bminlen == 1 then
  redis.call('del', prefix .. ":" .. min)
  redis.call('zrem', index, min)
end

-- Remove max if the cardinality between max and the set before max differs by -1
if bmaxlen - maxlen  == 1 then
  redis.call('del', prefix .. ":" .. max)
  redis.call('zrem', index, max)
end

-- Remove the member from all sets between min & max
for _, val in pairs(window) do
  redis.call('srem', prefix .. ":" .. val, member)
end

return redis.status_reply("OK")