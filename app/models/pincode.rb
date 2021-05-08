# frozen_string_literal: true

class Pincode < ApplicationRecord
  def default_maps_link
    "https://www.google.com/maps?q=#{CGI.escape [id, 'India'].join(' ')}"
  end
end
