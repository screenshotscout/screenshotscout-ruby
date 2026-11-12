# frozen_string_literal: true

require "screenshotscout"

# Reads SCREENSHOTSCOUT_ACCESS_KEY, and SCREENSHOTSCOUT_SECRET_KEY if it's set
client = ScreenshotScout::Client.new
options = ScreenshotScout::CaptureOptions.new(full_page: true, block_ads: true)

puts client.build_capture_url("https://example.com", options)
