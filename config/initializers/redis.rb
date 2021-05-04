$redis = ConnectionPool.new(size: 5, timeout: 5) { Redis.new }
$redirect = ConnectionPool::Wrapper.new(size: 3, timeout: 3) { Redis.new }