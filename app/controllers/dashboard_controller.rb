# frozen_string_literal: true

class DashboardController < ApplicationController
  # params: date, count, distance, pincode, lat, lon
  def index
    @date = params[:date].blank? ? Date.today : Date.parse(params[:date])
    date = @date.strftime('%d-%m-%Y')
    lat = 0
    lon = 0
    radius_km = [[params[:distance].to_i, 100].min, 10].max
    count = [[params[:count].to_i, 100].min, 10].max

    if params[:pincode].present? && params[:pincode]
      pincode_location = $redis.with { |r| r.geopos 'geopins', params[:pincode] }.compact.flatten
      lon, lat = pincode_location unless pincode_location.empty?
    end

    sessions_data = $redis.with do |r|
      r.geosearch "geosessions/#{date}", 'FROMLONLAT', lon, lat, 'BYRADIUS', radius_km, 'km',
                  'WITHDIST', 'ASC', 'COUNT', count
    end

    session_ids = sessions_data.map(&:first)
    @session_distances = sessions_data.each_with_object({}) { |sess, memo| memo[sess.first] = sess.last.to_f.round }

    sessions = $redis.with { |r| r.hmget "dates/#{date}/sessions", session_ids }
    sessions = sessions.map { |data| JSON.parse(data) }.each_with_object({}) { |s, memo| memo[s['session_id']] = s }
    @sessions = session_ids.map { |id| sessions[id] }

    center_ids = @sessions.map { |s| s['center_id'] }.uniq
    centers = $redis.with { |r| r.hmget 'centers', center_ids }
    @centers = centers.map { |data| JSON.parse(data) }.each_with_object({}) { |c, memo| memo[c['center_id']] = c.except('sessions', 'lat', 'long') }

    return unless params[:format] == 'json'

    render json: {
      date: @date,
      sessions: @sessions,
      centers: @centers,
      distances: @session_distances
    }
  end
end
