class Center < ApplicationRecord
  belongs_to :district
  has_many :sessions

  attribute :open, :time_only
  attribute :close, :time_only
end
