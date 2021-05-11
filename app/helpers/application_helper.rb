# frozen_string_literal: true

module ApplicationHelper
  def canonicalize(url)
    uri = URI.parse url
    uri.host = 'taketheshot.in'
    uri.scheme = 'https'
    uri.port = nil
    uri.to_s.html_safe
  end
end
