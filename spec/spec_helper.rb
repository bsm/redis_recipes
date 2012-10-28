ENV["REDIS_URL"] ||= 'redis://127.0.0.1:6379/9'

require 'bundler/setup'
require 'rspec'
require 'redis'

count = Redis.current.dbsize
unless count.zero?
  STDERR.puts
  STDERR.puts " !! WARNING!"
  STDERR.puts " !! ========"
  STDERR.puts " !!"
  STDERR.puts " !! Your Redis (test) database at #{Redis.current.id} contains #{count} keys."
  STDERR.puts " !! Running specs would wipe your database and result in potentail data loss."
  STDERR.puts " !! Please specify a REDIS_URL environment variable to point to an empty database."
  STDERR.puts
  abort
end

version = Redis.current.info["redis_version"]
unless version >= "2.5"
  STDERR.puts
  STDERR.puts " !! WARNING!"
  STDERR.puts " !! ========"
  STDERR.puts " !!"
  STDERR.puts " !! Your Redis (test) database at #{Redis.current.id} v#{version} is not suitable."
  STDERR.puts " !! Please upgrade to Redis 2.6, or higher."
  STDERR.puts
  abort
end

module RSpec::RedisHelper
  ROOT = File.expand_path("../../lib", __FILE__)

  def redis
    Redis.current
  end

  def evalsha(name, *args)
    part = File.basename(File.dirname(self.class.file_path)).to_sym
    redis.evalsha scripts[part][name], *args
  end

  def scripts
    @scripts ||= Dir[File.join(ROOT, "**/*.lua")].inject({}) do |result, file|
      part, name = file.sub(ROOT, "").sub(".lua", "").split("/").reject(&:empty?).map(&:to_sym)
      result[part] ||= {}
      result[part][name] = redis.script :load, File.read(file)
      result
    end
  end

end

RSpec.configure do |config|

  config.after do
    redis.unwatch
    redis.flushdb
  end

  config.include RSpec::RedisHelper

end
