class Center < ApplicationRecord
  belongs_to :district
  has_many :sessions

  attribute :open, :time_only
  attribute :close, :time_only

  def pincode_maps_link
    "https://www.google.com/maps?q=#{CGI.escape [district.state.name, pincode].join(' ')}"
  end
end
