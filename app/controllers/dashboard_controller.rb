# frozen_string_literal: true

class DashboardController < ApplicationController
  # params: date, count, distance, pincode, lat, lon
  def index
    @date = params[:date].blank? ? Date.today : Date.parse(params[:date])
    date = @date.strftime('%d-%m-%Y')
    @lat = params[:lat].present? ? params[:lat].to_f : 0
    @lon = params[:lon].present? ? params[:lon].to_f : 0
    radius_km = [[params[:distance].to_i, 100].min, 10].max

    if params[:pincode].present? && params[:pincode]
      pincode_location = $redis.with { |r| r.geopos 'geopins', params[:pincode] }.compact.flatten
      @lon, @lat = pincode_location unless pincode_location.empty?
      @lon = @lon.to_f
      @lat = @lat.to_f
    end

    @age = params[:age].blank? ? 45 : params[:age].to_i

    sessions_data = $redis.with do |r|
      r.geosearch "geosessions/#{date}", 'FROMLONLAT', @lon, @lat, 'BYRADIUS', radius_km, 'km',
                  'WITHDIST', 'ASC'
    end

    session_ids = sessions_data.map(&:first)
    @session_distances = sessions_data.each_with_object({}) { |sess, memo| memo[sess.first] = sess.last.to_f.round }

    @sessions = []
    @centers = {}

    unless session_ids.empty? || (@lat.zero? && @lon.zero?)
      sessions = $redis.with { |r| r.hmget "dates/#{date}/sessions", session_ids }
      sessions = sessions.map { JSON.parse(_1) }.each_with_object({}) do |s, memo|
        memo[s['session_id']] = s
      end
      @sessions = session_ids.map { |id| sessions[id] }

      center_ids = @sessions.map { |s| s['center_id'] }.uniq
      centers = $redis.with { |r| r.hmget 'centers', center_ids }
      @centers = centers.map { JSON.parse(_1) }.each_with_object({}) do |c, memo|
        memo[c['center_id']] = c.except('lat', 'long')
      end

      if params[:vaccine].present? && params[:vaccine] != 'ANY'
        @sessions = @sessions.select { |s| s['vaccine'] == params[:vaccine].to_s.upcase }
      end

      @sessions = @sessions.select { |s| s['min_age_limit'] <= @age }

    end

    return unless params[:format] == 'json'

    render json: {
      date: @date,
      sessions: @sessions,
      centers: @centers,
      distances: @session_distances
    }
  end
end
