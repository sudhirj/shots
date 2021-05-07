class Session < ApplicationRecord
  belongs_to :center
  delegate :pincode, to: :center
end
