if #KEYS ~= 1 or #ARGV ~= 1 then
  return redis.error_reply("wrong number of arguments")
end

local prefix = KEYS[1]
local value  = tonumber(ARGV[1])

if value == nil then
  return redis.error_reply("value is not numeric or out of range")
end

local members = {}
local pos     = redis.call('zrevrangebyscore', prefix .. ":~", value, "-inf", "limit", 0, 1)[1]

if pos then
  members = redis.call('smembers', prefix .. ":" .. pos)
end

return members