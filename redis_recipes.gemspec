# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.0'
  s.required_rubygems_version = ">= 1.3.6"

  s.name        = "redis_recipes"
  s.summary     = "Redis LUA recipes."
  s.description = "Require Redis 2.6.0 or higher"
  s.version     = "0.3.0"

  s.authors     = ["Black Square Media"]
  s.email       = "info@blacksquaremedia.com"
  s.homepage    = "https://github.com/bsm/redis_recipes"

  s.require_path = ['lib']
  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")

  s.add_development_dependency "redis", "~> 3.0.0"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
end
