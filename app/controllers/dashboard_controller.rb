# frozen_string_literal: true

class DashboardController < ApplicationController
  def index; end

  def show
    slug = params[:slug]
    pincode_places = looks_like_pincode?(slug) ? Place.where(pincode: slug.to_i) : []
    city_places = Place.where(city_slug: [slug, pincode_places.map(&:city_slug).uniq].flatten)

    @sessions = Session.includes(center: [:district])
                       .where(center: { pincode: [[city_places, pincode_places].flatten.map(&:pincode).uniq ] })
                       .where('date >= ? ', Time.zone.today)

    @center_session_groups = @sessions.group_by(&:center).sort_by do |center, sessions|
      [(center.pincode == slug.to_i ? -1 : 0),-sessions.sum(&:availability)]
    end
    @pincode_place_map = city_places.group_by(&:pincode).to_h

    @title_components = []
    @title_components.push city_places.sample.city
    @title_components.push pincode_places.sample.area unless pincode_places.empty?
    @title_components.reverse!
  end

  def jump
    if params[:lat].present? && params[:lon].present?
      nearest_pincode = $redis.with do |r|
        r.geosearch 'geo/pincodes', 'FROMLONLAT', params[:lon], params[:lat], 'BYRADIUS', 50, 'km', 'ASC', 'COUNT', 1
      end
      redirect_to nearest_pincode.empty? ? root_path : slug_path(nearest_pincode.first)
      return
    end

    redirect_to slug_path(params[:pincode]) if clean_pincode.present?
  end

  private

  def looks_like_pincode?(slug)
    slug.to_s.size == 6 && slug.to_i.to_s == slug.to_s
  end

  def clean_pincode
    pincode = params[:pincode]
    return nil if pincode.blank?
    return nil if pincode.to_s.size != 6
    return nil if pincode.to_i.to_s != pincode

    pincode
  end
end
