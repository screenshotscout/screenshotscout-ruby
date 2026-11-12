# frozen_string_literal: true

require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(
  response_type: ScreenshotScout::CaptureResponseType::JSON
)
response = client.capture("https://example.com", options)

puts response.result.screenshot_url
