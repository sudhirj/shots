# frozen_string_literal: true

agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:88.0) Gecko/20100101 Firefox/88.0'

namespace :loadup do
  task :states do
    states = HTTParty.get('https://cdn-api.co-vin.in/api/v2/admin/location/states',
                          headers: { 'User-Agent' => agent })
    pp states
    states['states'].each do |state|
      State.find_or_create_by(id: state['state_id'].to_i) do |s|
        s.name = state['state_name']
      end
    end
  end

  task :districts do
    State.all.each do |state|
      districts = HTTParty.get("https://cdn-api.co-vin.in/api/v2/admin/location/districts/#{state.id}",
                               headers: { 'User-Agent' => agent })
      pp districts
      districts['districts'].each do |district|
        District.find_or_create_by(id: district['district_id'].to_i) do |d|
          d.name = district['district_name']
          d.state = state
        end
      end
    end
  end

  task :centers do
    District.all.shuffle.each_with_index do |district, idx|
      centers_data = HTTParty.get(
        "https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=#{district.id}&date=#{Date.today.strftime('%d-%m-%Y')}", headers: { 'User-Agent' => agent }
      )
      break if centers_data.code != 200

      pp centers_data
      puts "Fetched No. #{district.id} / #{district.name}, #{idx + 1}/#{District.count}"
      centers_data['centers'].to_a.each do |center_data|
        center = Center.find_or_initialize_by(id: center_data['center_id'].to_i) do |c|
          c.name = center_data['name']
          c.address = center_data['address']
          c.block = center_data['block_name']
          c.pincode = center_data['pincode']
          c.open = Tod::TimeOfDay.try_parse(center_data['from'])
          c.close = Tod::TimeOfDay.try_parse(center_data['to'])
          c.fee_type = center_data['fee_type'].to_s.upcase
          c.district = district
        end
        center.save!
        center_data['sessions'].to_a.each do |session_data|
          center.sessions.find_or_initialize_by(id: session_data['session_id']) do |s|
            s.date = Date.parse(session_data['date'])
            s.availability = session_data['available_capacity']
            s.min_age = session_data['min_age_limit']
            s.vaccine = session_data['vaccine']
          end.save!
        end
      end

      sleep 5
    end
  end

  task :loopy do
    loop do
      Rake::Task['loadup:states'].execute
      Rake::Task['loadup:districts'].execute
      Rake::Task['loadup:centers'].execute
    end
  end

  task :geopins do
    CSV.open(Rails.root.join('IN.txt'), 'r', col_sep: "\t").each do |row|
      Pincode.find_or_initialize_by(id: row[1].to_i) do |pc|
        pc.lat = row[9].to_f
        pc.lon = row[10].to_f
      end.save!
    end
  end

  task geoindex: [:environment] do
    $redis.with do |r|
      r.pipelined do
        Pincode.find_each do |pc|
          r.geoadd 'geo/pincodes', pc.lon, pc.lat, pc.id
        end
      end
    end
  end

end
