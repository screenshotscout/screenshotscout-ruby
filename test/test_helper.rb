# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "json"
require "minitest/autorun"
require "screenshotscout"

# Keys set in the developer's own environment must not reach these tests.
ENV.delete("SCREENSHOTSCOUT_ACCESS_KEY")
ENV.delete("SCREENSHOTSCOUT_SECRET_KEY")

module EnvironmentHelper
  private

  # Runs the block with the given variables set, then restores ENV as it was.
  def with_env(values)
    saved = ENV.to_h
    ENV.update(values)
    yield
  ensure
    ENV.replace(saved)
  end
end

class RecordingTransport
  attr_reader :requests

  def initialize(response = nil, &response_factory)
    @response = response || TestResponses.binary
    @response_factory = response_factory
    @requests = []
  end

  def call(request)
    @requests << request
    return @response_factory.call(request) unless @response_factory.nil?

    @response
  end
end

module TestResponses
  module_function

  def binary(
    body: "\x01".b,
    status: 200,
    reason_phrase: "OK",
    headers: { "content-type" => ["image/png"] }
  )
    ScreenshotScout::RawResponse.new(
      status: status,
      reason_phrase: reason_phrase,
      headers: headers,
      content_type: headers.find { |name, _values| name.downcase == "content-type" }&.last&.first,
      body: body
    )
  end

  def json(body: "{}", status: 200, reason_phrase: "OK", content_type: "application/json", headers: {})
    binary(
      body: body,
      status: status,
      reason_phrase: reason_phrase,
      headers: { "content-type" => [content_type] }.merge(headers)
    )
  end
end
