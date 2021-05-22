# frozen_string_literal: true

AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:88.0) Gecko/20100101 Firefox/88.0'

namespace :loadup do
  task states: [:environment] do
    states = keep_trying_to_get('https://cdn-api.co-vin.in/api/v2/admin/location/states')
    pp states
    states['states'].each do |state|
      State.find_or_create_by(id: state['state_id'].to_i) do |s|
        s.name = state['state_name']
      end
    end
  end

  task districts: [:environment] do
    State.all.each do |state|
      districts = keep_trying_to_get("https://cdn-api.co-vin.in/api/v2/admin/location/districts/#{state.id}")
      pp districts
      districts['districts'].each do |district|
        District.find_or_create_by(id: district['district_id'].to_i) do |d|
          d.name = district['district_name']
          d.state = state
        end
      end
    end
  end

  def keep_trying_to_get(url)
    data = {}
    loop do
      data = HTTParty.get(url, headers: { 'User-Agent' => AGENT })
      break if data.code == 200

      exponential_backoff *= 4
      puts "Couldn't fetch data, sleeping for #{exponential_backoff} seconds..."
      sleep exponential_backoff.seconds
    end
    data
  end

  task centers: [:environment] do
    ActiveRecord::Base.logger = Logger.new($stdout)
    District.all.shuffle.each_with_index do |district, idx|
      centers_data = keep_trying_to_get "https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=#{district.id}&date=#{Date.today.strftime('%d-%m-%Y')}"

      pp centers_data
      puts "Fetched No. #{district.id} / #{district.name}, #{idx + 1}/#{District.count}"

      centers = centers_data['centers'].to_a.map do |center_data|
        {
          id: center_data['center_id'],
          name: center_data['name'],
          address: center_data['address'],
          block: center_data['block_name'],
          pincode: center_data['pincode'],
          open: Tod::TimeOfDay.try_parse(center_data['from']),
          close: Tod::TimeOfDay.try_parse(center_data['to']),
          fee_type: center_data['fee_type'].to_s.upcase,
          district_id: district.id,
          updated_at: DateTime.now
        }
      end
      Center.upsert_all(centers, unique_by: [:id]) unless centers.empty?

      sessions = centers_data['centers'].to_a.flat_map do |center_data|
        center_data['sessions'].to_a.map do |session_data|
          {
            id: session_data['session_id'],
            date: Date.parse(session_data['date']),
            availability: session_data['available_capacity'],
            min_age: session_data['min_age_limit'],
            vaccine: session_data['vaccine'],
            center_id: center_data['center_id'],
            updated_at: DateTime.now
          }
        end
      end
      Session.upsert_all(sessions, unique_by: [:id]) unless sessions.empty?
    end
  end

  task loopy: [:environment] do
    loop do
      Rake::Task['loadup:states'].execute
      Rake::Task['loadup:districts'].execute
      Rake::Task['loadup:centers'].execute
    end
  end

  task geopins: [:environment] do
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

  task mapmaker: [:environment] do
    ActiveRecord::Base.logger = Logger.new($stdout)
    Center.find_each { |c| Pincode.find_or_create_by! id: c.pincode }
    Pincode.find_each do |pincode|
      $redis.with { |r| r.geoadd 'geo/pincodes', pincode.lon, pincode.lat, pincode.id }
      next if pincode.map_image.present?

      doc = Nokogiri::HTML(URI.open(pincode.default_maps_link))
      image = doc.css('meta[property="og:image"]').first.attr('content')
      pp pincode.default_maps_link, image
      pincode.update map_url: pincode.default_maps_link, map_image: image
    end
  end

  task geodata: [:environment] do
    ActiveRecord::Base.logger = Logger.new($stdout)
    Geodatum.delete_all
    CSV.open(Rails.root.join('IN.txt'), 'r', col_sep: "\t").each_slice(10_000) do |rows|
      insertions = rows.map do |row|
        {
          pincode: row[1].to_i,
          place: row[2],
          admin1: row[3],
          admin2: row[5],
          admin3: row[7],
          lat: row[9].to_f,
          lon: row[10].to_f,
          accuracy: row[11].to_i,
          created_at: Time.now,
          updated_at: Time.now
        }
      end
      Geodatum.insert_all!(insertions)
    end
  end
end
# 0 country code      : iso country code, 2 characters
# 1 postal code       : varchar(20)
# 2 place name        : varchar(180)
# 3 admin name1       : 1. order subdivision (state) varchar(100)
# 4 admin code1       : 1. order subdivision (state) varchar(20)
# 5 admin name2       : 2. order subdivision (county/province) varchar(100)
# 6 admin code2       : 2. order subdivision (county/province) varchar(20)
# 7 admin name3       : 3. order subdivision (community) varchar(100)
# 8 admin code3       : 3. order subdivision (community) varchar(20)
# 9 latitude          : estimated latitude (wgs84)
# 10 longitude         : estimated longitude (wgs84)
# 11 accuracy          : accuracy of lat/lng from 1=estimated, 4=geonameid, 6=centroid of addresses or
