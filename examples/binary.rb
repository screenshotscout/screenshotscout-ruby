# frozen_string_literal: true

require "screenshotscout"

access_key = ENV.fetch("SCREENSHOTSCOUT_ACCESS_KEY")
secret_key = ENV.fetch("SCREENSHOTSCOUT_SECRET_KEY", nil)
client = ScreenshotScout::Client.new(access_key: access_key, secret_key: secret_key)
options = ScreenshotScout::CaptureOptions.new(full_page: true)
response = client.capture("https://example.com", options)

File.binwrite("screenshot.png", response.bytes)
puts response.screenshot_url
