# frozen_string_literal: true

require "socket"

require_relative "test_helper"

class ResponseAndTransportTest < Minitest::Test
  include EnvironmentHelper

  def test_binary_response_retains_bytes_metadata_and_raw_response
    body = "\x00\x01\x02\xFF".b
    raw = TestResponses.binary(
      body: body,
      status: 201,
      reason_phrase: "Created",
      headers: {
        "content-type" => ["image/png"],
        "screenshot-scout-cache-status" => ["HIT"],
        "screenshot-scout-screenshot-url" => ["https://cdn.example/screenshot.png"],
        "screenshot-scout-screenshot-url-expires-at" => ["2026-07-14T00:00:00Z"],
        "set-cookie" => ["a=1; Path=/", "b=2; Path=/"]
      }
    )

    response = client(RecordingTransport.new(raw)).capture("https://example.com")

    assert_instance_of ScreenshotScout::BinaryCaptureResponse, response
    assert_equal body, response.bytes
    assert_same response.raw_response.body, response.bytes
    assert_equal "https://cdn.example/screenshot.png", response.screenshot_url
    assert_equal "2026-07-14T00:00:00Z", response.screenshot_url_expires_at
    assert_equal "HIT", response.cache_status
    assert_equal 201, response.raw_response.status
    assert_equal "Created", response.raw_response.reason_phrase
    assert_equal "image/png", response.raw_response.content_type
    assert_equal ["a=1; Path=/", "b=2; Path=/"], response.raw_response.header("Set-Cookie")
  end

  def test_empty_content_type_is_treated_as_binary
    body = "\x01\x02".b
    raw = TestResponses.binary(body: body, headers: { "content-type" => [""] })

    response = client(RecordingTransport.new(raw)).capture("https://example.com")

    assert_instance_of ScreenshotScout::BinaryCaptureResponse, response
    assert_equal body, response.bytes
    assert_equal "", response.raw_response.content_type
  end

  def test_json_response_retains_documented_and_additional_fields
    body = JSON.generate(
      "screenshot_url" => "https://cdn.example/screenshot.png",
      "cache_status" => "miss",
      "request_id" => "request-123",
      "future" => { "nested" => true }
    )
    raw = TestResponses.json(
      body: body,
      content_type: "application/vnd.screenshotscout+json; charset=utf-8"
    )
    options = ScreenshotScout::CaptureOptions.new(
      response_type: ScreenshotScout::CaptureResponseType::JSON
    )

    response = client(RecordingTransport.new(raw)).capture("https://example.com", options)

    assert_instance_of ScreenshotScout::JsonCaptureResponse, response
    assert_equal "https://cdn.example/screenshot.png", response.result.screenshot_url
    assert_equal "miss", response.result.cache_status
    assert_nil response.result.screenshot_url_expires_at
    assert_equal(
      { "request_id" => "request-123", "future" => { "nested" => true } },
      response.result.additional_fields
    )
    assert_equal body, response.raw_response.body
  end

  def test_known_response_types_reject_successful_wrong_media_types
    json_raw = TestResponses.json(body: JSON.generate("screenshot_url" => "https://cdn.example/a.png"))
    error = assert_raises(ScreenshotScout::ResponseDecodingError) do
      client(RecordingTransport.new(json_raw)).capture("https://example.com")
    end
    assert_match(/json response when binary was requested/, error.message)
    assert_same json_raw, error.raw_response
    assert_instance_of TypeError, error.cause

    binary_raw = TestResponses.binary(body: "\x01\x02".b)
    options = ScreenshotScout::CaptureOptions.new(
      response_type: ScreenshotScout::CaptureResponseType::JSON
    )
    error = assert_raises(ScreenshotScout::ResponseDecodingError) do
      client(RecordingTransport.new(binary_raw)).capture("https://example.com", options)
    end
    assert_match(/binary response when json was requested/, error.message)
    assert_same binary_raw, error.raw_response
  end

  def test_open_response_type_uses_the_actual_media_type
    raw = TestResponses.json(body: JSON.generate("screenshot_url" => "https://cdn.example/a.png"))
    options = ScreenshotScout::CaptureOptions.new(response_type: "future-response")

    response = client(RecordingTransport.new(raw)).capture("https://example.com", options)

    assert_instance_of ScreenshotScout::JsonCaptureResponse, response
    assert_equal "https://cdn.example/a.png", response.result.screenshot_url
  end

  def test_malformed_successful_json_is_a_decoding_failure_with_raw_access
    ["{", "[]", '{"screenshot_url":123}', '{"screenshot_url":null}'].each do |body|
      raw = TestResponses.json(body: body)
      options = ScreenshotScout::CaptureOptions.new(
        response_type: ScreenshotScout::CaptureResponseType::JSON
      )

      error = assert_raises(ScreenshotScout::ResponseDecodingError) do
        client(RecordingTransport.new(raw)).capture("https://example.com", options)
      end

      assert_same raw, error.raw_response
      assert_equal body, error.raw_response.body
    end
  end

  def test_api_failures_retain_parsed_fields_and_exact_raw_response
    error_body = {
      "error_code" => "invalid_options",
      "error_message" => "One or more options are invalid.",
      "errors" => [{ "option" => "format", "message" => "Unsupported." }],
      "request_id" => "request-456"
    }
    encoded = JSON.generate(error_body)
    raw = TestResponses.json(
      body: encoded,
      status: 400,
      reason_phrase: "Bad Request",
      headers: { "x-request-id" => ["request-456"] }
    )

    error = assert_raises(ScreenshotScout::APIError) do
      client(RecordingTransport.new(raw)).capture("not-semantically-validated")
    end

    assert_equal 400, error.status
    assert_equal "invalid_options", error.error_code
    assert_equal "One or more options are invalid.", error.error_message
    assert_equal error_body.fetch("errors"), error.errors
    assert_predicate error, :response_body?
    assert_equal error_body, error.response_body
    assert_same raw, error.raw_response
    assert_equal ["request-456"], error.raw_response.header("X-Request-ID")
    assert_equal encoded, error.raw_response.body
  end

  def test_non_json_and_redirect_api_failures_keep_raw_access_without_retrying
    raw = TestResponses.binary(
      body: "redirect",
      status: 302,
      reason_phrase: "Found",
      headers: { "location" => ["https://other.example/v1/capture"] }
    )
    transport = RecordingTransport.new(raw)

    error = assert_raises(ScreenshotScout::APIError) do
      client(transport).capture("https://example.com")
    end

    assert_equal 302, error.status
    assert_nil error.error_code
    refute_predicate error, :response_body?
    assert_equal "redirect", error.raw_response.body
    assert_equal 1, transport.requests.length
  end

  def test_valid_json_null_api_body_is_distinguishable_from_invalid_json
    raw = TestResponses.json(body: "null", status: 500, reason_phrase: "Internal Server Error")

    error = assert_raises(ScreenshotScout::APIError) do
      client(RecordingTransport.new(raw)).capture("https://example.com")
    end

    assert_predicate error, :response_body?
    assert_nil error.response_body
  end

  def test_transport_failures_retain_the_native_cause_and_are_not_retried
    cause = IOError.new("socket closed")
    calls = 0
    transport = Object.new
    transport.define_singleton_method(:call) do |_request|
      calls += 1
      raise cause
    end

    error = assert_raises(ScreenshotScout::TransportError) do
      client(transport).capture("https://example.com")
    end

    assert_same cause, error.cause
    assert_equal 1, calls
  end

  def test_transport_must_return_a_raw_response
    transport = Object.new
    transport.define_singleton_method(:call) { |_request| Object.new }

    error = assert_raises(ScreenshotScout::TransportError) do
      client(transport).capture("https://example.com")
    end

    assert_instance_of TypeError, error.cause
  end

  def test_a_transport_failure_names_screenshotscout_base_url_only_when_the_base_url_came_from_it
    cause = IOError.new("connection refused")
    transport = Object.new
    transport.define_singleton_method(:call) { |_request| raise cause }
    message = "Screenshot Scout request failed before a complete HTTP response body was received."
    base_url_variable = { "SCREENSHOTSCOUT_BASE_URL" => "http://localhost:8787" }

    [
      [base_url_variable, nil, "#{message} The base URL comes from SCREENSHOTSCOUT_BASE_URL."],
      [base_url_variable, "http://localhost:8787", message],
      [{}, nil, message]
    ].each do |environment, base_url, expected_message|
      screenshot_client = with_env(environment) { client(transport, base_url: base_url) }

      error = assert_raises(ScreenshotScout::TransportError) { screenshot_client.capture("https://example.com") }

      assert_equal expected_message, error.message
      assert_same cause, error.cause
    end
  end

  def test_a_base_url_that_cannot_be_parsed_fails_as_a_transport_error_and_built_urls_use_it_as_given
    screenshot_client = ScreenshotScout::Client.new(access_key: "key", base_url: "not a url")

    error = assert_raises(ScreenshotScout::TransportError) { screenshot_client.capture("https://example.com") }

    # The default transport parses the URL before it opens a connection, so nothing was sent.
    assert_instance_of URI::InvalidURIError, error.cause
    assert_equal(
      "not a url/v1/capture?access_key=key&url=https%3A%2F%2Fexample.com",
      screenshot_client.build_capture_url("https://example.com")
    )
  end

  def test_default_net_http_adapter_buffers_response_and_ignores_environment_proxy
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr.fetch(1)
    observed_request = Queue.new
    server_thread = Thread.new do
      socket = server.accept
      request_lines = []
      while (line = socket.gets)
        break if line == "\r\n"

        request_lines << line
      end
      observed_request << request_lines
      body = "\x00\x01\xFF".b
      socket.write(
        "HTTP/1.1 201 Created\r\n" \
        "Content-Type: image/png\r\n" \
        "X-Test: one\r\n" \
        "X-Test: two\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n"
      )
      socket.write(body)
      socket.close
    end
    previous_proxy = ENV.fetch("http_proxy", nil)
    ENV["http_proxy"] = "http://127.0.0.1:1"
    request = ScreenshotScout::TransportRequest.new(
      method: ScreenshotScout::CaptureHttpMethod::GET,
      url: "http://127.0.0.1:#{port}/capture?url=test",
      headers: { "Authorization" => "Bearer key" }
    )

    response = ScreenshotScout::NetHttpTransport.new.call(request)

    assert_equal 201, response.status
    assert_equal "Created", response.reason_phrase
    assert_equal "image/png", response.content_type
    assert_equal "\x00\x01\xFF".b, response.body
    assert_equal %w[one two], response.header("X-Test")
    lines = observed_request.pop
    assert_equal "GET /capture?url=test HTTP/1.1\r\n", lines.first
    assert_includes lines.map(&:downcase), "authorization: bearer key\r\n"
  ensure
    previous_proxy.nil? ? ENV.delete("http_proxy") : ENV["http_proxy"] = previous_proxy
    server&.close
    server_thread&.join(2)
  end

  def test_default_net_http_adapter_waits_longer_than_the_longest_capture
    uri = URI("https://api.screenshotscout.com/v1/capture")

    session = ScreenshotScout::NetHttpTransport.new.send(:build_session, uri)

    assert_equal 300, session.read_timeout
  end

  private

  def client(transport, base_url: nil)
    ScreenshotScout::Client.new(access_key: "key", base_url: base_url, transport: transport)
  end
end
