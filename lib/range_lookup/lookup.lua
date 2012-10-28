if #KEYS ~= 1 or #ARGV ~= 1 then
  return redis.error_reply("wrong number of arguments")
end

local prefix = KEYS[1]
local value  = tonumber(ARGV[1])

if value == nil then
  return redis.error_reply("value is not numeric or out of range")
end

local members = {}
local score   = redis.call('zscore', prefix .. ":~", value)

if score then -- Do we have an exact match?
  members = redis.call('smembers', prefix .. ":" .. score)
else
  local before  = redis.call('zrevrangebyscore', prefix .. ":~", value, "-inf", "limit", 0, 1)[1]
  if before then
    local after = redis.call('zrangebyscore', prefix .. ":~", value, "inf", "limit", 0, 1)[1]
    if after then
      members = redis.call('sinter', prefix .. ":" .. before, prefix .. ":" .. after)
    end
  end
end

return members