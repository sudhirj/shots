# frozen_string_literal: true

pool_size = ENV.fetch("RAILS_MAX_THREADS") { 5 }
if ENV['REDIS_URL'].present?
  $redis = ConnectionPool.new(size: pool_size, timeout: 5) { Redis.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }) }
  $redirect = ConnectionPool::Wrapper.new(size: 3, timeout: 3) { Redis.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }) }
else
  $redis = ConnectionPool.new(size: pool_size, timeout: 5) { Redis.new }
  $redirect = ConnectionPool::Wrapper.new(size: 3, timeout: 3) { Redis.new }
end
