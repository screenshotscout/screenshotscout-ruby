# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "json"
require "minitest/autorun"
require "screenshotscout"

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
