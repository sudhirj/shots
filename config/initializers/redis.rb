# frozen_string_literal: true

$redis =
  ConnectionPool.new(size: 5, timeout: 5) do
    if ENV['REDIS_URL'].present?
      Redis.new(url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
    else
      Redis.new
    end
  end


