# frozen_string_literal: true

require "screenshotscout"

access_key = ENV.fetch("SCREENSHOTSCOUT_ACCESS_KEY")
client = ScreenshotScout::Client.new(access_key: access_key)
options = ScreenshotScout::CaptureOptions.new(
  response_type: ScreenshotScout::CaptureResponseType::JSON
)
response = client.capture("https://example.com", options)

puts response.result.screenshot_url
