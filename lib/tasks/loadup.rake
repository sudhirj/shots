# frozen_string_literal: true

agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:88.0) Gecko/20100101 Firefox/88.0'

namespace :loadup do
  task :states do
    $redis.with do |redis|
      states = HTTParty.get('https://cdn-api.co-vin.in/api/v2/admin/location/states',
                            headers: { 'User-Agent' => agent })
      puts states
      redis.pipelined do
        states['states'].each do |state|
          redis.hset 'states', state['state_id'], state['state_name']
        end
      end
    end
  end

  task :districts do
    $redis.with do |redis|
      states = redis.hgetall 'states'
      redis.pipelined do
        states.each do |id, _state_name|
          districts = HTTParty.get("https://cdn-api.co-vin.in/api/v2/admin/location/districts/#{id}",
                                   headers: { 'User-Agent' => agent })
          districts['districts'].each do |district|
            redis.hset 'districts', district['district_id'], district['district_name']
          end
        end
      end
    end
  end

  task :centers do
    $redis.with do |redis|
      districts = redis.hkeys 'districts'
      districts.shuffle.each_with_index do |id, idx|
        centers = HTTParty.get(
          "https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=#{id}&date=#{Date.today.strftime('%d-%m-%Y')}", headers: { 'User-Agent' => agent }
        )
        break if centers.code != 200

        puts "Fetched No. #{id}, #{idx + 1}/#{districts.size}"
        centers['centers'].each do |center|
          redis.hset 'centers', center['center_id'], center.merge(district_id: id.to_i).to_json
        end
        sleep 5
      end
    end
  end

  task index: [:environment] do
    $redis.with do |redis|
      centers = redis.hgetall('centers').map { |_id, center_json| JSON.parse(center_json) }
      pincodes = centers.map { |c| c['pincode'] }
      positions = redis.geopos 'geopins', pincodes
      pincode_map = pincodes.zip(positions).each_with_object({}) do |c, memo|
        memo[c.first] = c.last || []
      end
      redis.pipelined do
        centers.each do |center|
          puts "Indexing #{%w[name district_name state_name].map{center[_1]}.join(' / ')}"
          position = pincode_map[center['pincode']]
          center['sessions'].each do |session|
            redis.geoadd "geosessions/#{session['date']}", position.first.to_f, position.last.to_f,
                         session['session_id']
            redis.hset "dates/#{session['date']}/sessions", session['session_id'],
                       session.merge(center_id: center['center_id']).to_json
          end
        end
      end
    end
  end

  task :geopin do
    $redis.with do |redis|
      redis.pipelined do
        CSV.open(Rails.root.join('IN.txt'), 'r', col_sep: "\t").each do |row|
          redis.geoadd 'geopins', row[10], row[9], row[1]
          pp [row[1], row[9], row[10]]
        end
      end
    end
  end

  task :dump_centers do
    CSV.open(Rails.root.join('centers.csv'), 'w') do |csv|
      centers = $redirect.hgetall 'centers'
      centers.each do |_id, center_json|
        center = JSON.parse(center_json)
        csv << %w[center_id name address block_name district_name state_name pincode].map do |k|
          center[k]
        end
      end
    end
  end

  task :shift do
    dest = Redis.new(url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
    src = Redis.new(url: 'redis://localhost:6379')

    dest.pipelined do
      %w[states districts centers].each do |key|
        src.hgetall(key).each do |state|
          dest.hset key, state
        end
      end
    end
  end
end
