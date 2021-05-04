# frozen_string_literal: true

namespace :loadup do
  task :states do
    states = HTTParty.get('https://cdn-api.co-vin.in/api/v2/admin/location/states')
    states['states'].each do |state|
      $redirect.hset 'states', state['state_id'], state['state_name']
    end
  end

  task :districts do
    states = $redirect.hgetall 'states'
    states.each do |id, _state_name|
      districts = HTTParty.get("https://cdn-api.co-vin.in/api/v2/admin/location/districts/#{id}")
      districts['districts'].each do |district|
        $redirect.hset 'districts', district['district_id'], district['district_name']
        $redirect.sadd "states/#{id}/districts", district['district_id']
        $redirect.set "districts/#{district['district_id']}/state", id
      end
    end
  end

  task :centers do
    districts = $redirect.hkeys 'districts'
    districts.shuffle.each_with_index do |id, idx|
      centers = HTTParty.get("https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=#{id}&date=#{Date.today.strftime('%d-%m-%Y')}")
      break if centers.code != 200

      puts "Fetched No. #{id}, #{idx + 1}/#{districts.size}"
      centers['centers'].each do |center|
        $redirect.hset 'centers', center['center_id'], center.to_json
      end
      sleep 5
    end
  end

  task :index do
    $redis.with do |redis|
      centers = $redirect.hgetall 'centers'
      centers.each do |_id, center_json|
        center = JSON.parse(center_json)
        redis.sadd 'pincodes', center['pincode']
        redis.hset "pincodes/#{center['pincode']}/centers", center['center_id'], center.to_json
        position = redis.geopos('geopins', center['pincode']).first || []

        center['sessions'].each do |session|
          redis.geoadd "geosessions/#{session['date']}", position.first.to_f, position.last.to_f, session['session_id']
          redis.hset "dates/#{session['date']}/sessions", session['session_id'],
                     session.merge(center_id: center['center_id']).to_json
        end
      end
    end
  end

  task :geopin do
    CSV.open(Rails.root.join('IN.txt'), 'r', col_sep: "\t").each do |row|
      $redirect.geoadd 'geopins', row[10], row[9], row[1]
      pp [row[1], row[9], row[10]]
    end
  end

  task :dump_centers do
    CSV.open(Rails.root.join('centers.csv'), 'w') do |csv|
      centers = $redirect.hgetall 'centers'
      centers.each do |_id, center_json|
        center = JSON.parse(center_json)
        csv << %w[center_id name address block_name district_name state_name pincode ].map do |k|
          center[k]
        end
      end
    end
  end
end
