# frozen_string_literal: true

require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(full_page: true)
response = client.capture("https://example.com", options)

File.binwrite("screenshot.png", response.bytes)
puts response.screenshot_url
