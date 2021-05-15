class Geodatum < ApplicationRecord
  def short_list
    [clean_place, admin2].reject(&:blank?).compact
  end

  def clean_place
    place.gsub("(#{admin2})", '').strip
  end
end
