# frozen_string_literal: true

class DashboardController < ApplicationController
  # params: date, count, distance, pincode, lat, lon
  def index
    @date = params[:date].blank? ? Time.zone.today : Date.parse(params[:date])
    @lat = params[:lat].present? ? params[:lat].to_f : 0
    @lon = params[:lon].present? ? params[:lon].to_f : 0
    radius_km = [[params[:distance].to_i, 100].min, 25].max

    if params[:pincode].present? && params[:pincode]
      pincode = Pincode.find_by(id: params[:pincode])
      if pincode.present?
        @lat = pincode.lat
        @lon = pincode.lon
      end
    end

    @age = params[:age].blank? ? 45 : params[:age].to_i

    pincodes_geodata = $redis.with do |r|
      r.geosearch 'geo/pincodes', 'FROMLONLAT', @lon, @lat, 'BYRADIUS', radius_km, 'km',
                  'WITHDIST', 'ASC'
    end

    pincode_distance_map = pincodes_geodata.each_with_object({}) do |data, memo|
      memo[data.first.to_i] = data.last.to_f
    end

    @sessions = Session.includes(:center).where(center: { pincode: pincode_distance_map.keys }, date: @date)
    @sessions = @sessions.where('min_age <= ?', @age)
    if params[:vaccine].present? && params[:vaccine] != 'ANY'
      @sessions = @sessions.where(vaccine: params[:vaccine].to_s.upcase)
    end

    @session_distances = @sessions.each_with_object({}) do |sess, memo|
      memo[sess.id] = pincode_distance_map[sess.pincode].round
    end.sort_by { [_2, _1] }

    @sessions = @sessions.each_with_object({}) do
      _2[_1.id] = _1
    end

    return unless params[:format] == 'json'

    @centers = @sessions.values.map(&:center).uniq.each_with_object({}) { _2[_1.id] = _1 }
    render json: {
      date: @date,
      sessions: @sessions,
      centers: @centers,
      distances: @session_distances
    }
  end

  def show
    @pincode = params[:pincode].to_i
    pincodes_geodata = $redis.with do |r|
      r.geosearch 'geo/pincodes', 'FROMMEMBER', @pincode, 'BYRADIUS', 25, 'km',
                  'WITHDIST', 'ASC'
    end

    @pincode_distance_map = pincodes_geodata.each_with_object({}) do |data, memo|
      memo[data.first.to_i] = data.last.to_f
    end

    @sessions = Session.includes(:center)
                       .where(center: { pincode: @pincode_distance_map.keys })
                       .where('date >= ? ', Time.zone.today)

    @center_session_groups = @sessions.group_by(&:center).sort_by do |center, _sessions|
      @pincode_distance_map[center.pincode]
    end

    @geodata = Geodatum.where(pincode: @center_session_groups.map(&:first).map(&:pincode).uniq).each_with_object({}) do |data, memo|
      memo[data.pincode] = data unless memo[data.pincode].present? && memo[data.pincode].accuracy > data.accuracy
    end

    @pincode_geodata = Geodatum.where(pincode: @pincode).order(:accuracy).last
  end
end
