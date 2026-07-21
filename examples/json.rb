# frozen_string_literal: true

require "screenshotscout"

access_key = ENV.fetch("SCREENSHOTSCOUT_ACCESS_KEY")
secret_key = ENV.fetch("SCREENSHOTSCOUT_SECRET_KEY", nil)
client = ScreenshotScout::Client.new(access_key: access_key, secret_key: secret_key)
options = ScreenshotScout::CaptureOptions.new(
  response_type: ScreenshotScout::CaptureResponseType::JSON
)
response = client.capture("https://example.com", options)

puts response.result.screenshot_url
