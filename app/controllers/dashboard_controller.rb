# frozen_string_literal: true

class DashboardController < ApplicationController
  def index; end

  def show
    @pincode = params[:pincode].to_i

    begin
      pincodes_geodata = $redis.with do |r|
        r.geosearch 'geo/pincodes', 'FROMMEMBER', @pincode, 'BYRADIUS', 25, 'km',
                    'WITHDIST', 'ASC'
      end
    rescue StandardError
      redirect_to root_path
      return
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

    pincodes = @center_session_groups.map(&:first).map(&:pincode).to_set + [@pincode].to_set
    geodata = Geodatum.where(pincode: pincodes.to_a).to_a
    @geodata = geodata.each_with_object({}) do |data, memo|
      memo[data.pincode] = data unless memo[data.pincode].present? && memo[data.pincode].accuracy > data.accuracy
    end
    @pincode_geodata = geodata.select { _1.pincode == @pincode }.max_by(&:accuracy)
  end

  def jump
    if params[:lat].present? && params[:lon].present?
      nearest_pincode = $redis.with do |r|
        r.geosearch 'geo/pincodes', 'FROMLONLAT', params[:lon], params[:lat], 'BYRADIUS', 50, 'km', 'ASC', 'COUNT', 1
      end
      redirect_to nearest_pincode.empty? ? root_path : pincode_path(nearest_pincode.first)
      return
    end

    redirect_to pincode_path(params[:pincode]) if clean_pincode.present?
  end

  private

  def clean_pincode
    pincode = params[:pincode]
    return nil if pincode.blank?
    return nil if pincode.to_s.size != 6
    return nil if pincode.to_i.to_s != pincode

    pincode
  end
end
