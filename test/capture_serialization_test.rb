# frozen_string_literal: true

require_relative "test_helper"

class CaptureSerializationTest < Minitest::Test
  def test_configuration_validates_credentials_and_transport
    assert_raises(ScreenshotScout::ConfigurationError) { ScreenshotScout::Client.new }
    assert_raises(ScreenshotScout::ConfigurationError) do
      ScreenshotScout::Client.new(access_key: "   ")
    end
    assert_raises(ScreenshotScout::ConfigurationError) do
      ScreenshotScout::Client.new(access_key: "key with spaces")
    end
    assert_raises(ScreenshotScout::ConfigurationError) do
      ScreenshotScout::Client.new(access_key: "key", secret_key: "")
    end
    assert_raises(ScreenshotScout::ConfigurationError) do
      ScreenshotScout::Client.new(access_key: "key", transport: Object.new)
    end

    client = ScreenshotScout::Client.new(access_key: "key", transport: RecordingTransport.new)
    assert_instance_of ScreenshotScout::Client, client
  end

  def test_constants_are_frozen_and_service_values_remain_open
    assert_predicate ScreenshotScout::CaptureHttpMethod::GET, :frozen?
    assert_predicate ScreenshotScout::CaptureHttpMethod::POST, :frozen?
    assert_predicate ScreenshotScout::CaptureFormat::WEBP, :frozen?

    options = ScreenshotScout::CaptureOptions.new(format: "future-format")
    assert_equal "future-format", options.format
  end

  def test_post_is_default_and_serializes_the_complete_option_surface
    transport = RecordingTransport.new
    client = client(transport, access_key: "access-key")
    options = ScreenshotScout::CaptureOptions.new(
      format: "future-format",
      response_type: "future-response",
      country: "",
      proxy: "",
      geolocation_latitude: 0,
      geolocation_longitude: 0,
      geolocation_accuracy: 0,
      cookies: ["session=a", "session=a", ""],
      headers: ["X-Test:one", "X-Test:one", ""],
      timeout: 0,
      wait_until: "future-wait-state",
      navigation_timeout: 0,
      delay: 0,
      device: "",
      device_viewport_width: 0,
      device_viewport_height: 0,
      device_scale_factor: 0,
      device_is_mobile: false,
      device_has_touch: false,
      device_user_agent: "",
      timezone: "",
      media_type: "future-media",
      color_scheme: "future-scheme",
      reduced_motion: false,
      full_page: false,
      full_page_pre_scroll: false,
      full_page_pre_scroll_step: 0,
      full_page_pre_scroll_step_delay: 0,
      full_page_max_height: 0,
      block_cookie_banners: false,
      block_ads: false,
      block_chat_widgets: false,
      hide_selectors: [".same", ".same", ""],
      click_selectors: ["#first", "#first", ""],
      click_all_selectors: [".all", ".all", ""],
      inject_css: ["", "body { color: red; }"],
      inject_js: ["", "document.title = 'x';"],
      bypass_csp: false,
      selector: "",
      clip_x: 0,
      clip_y: 0,
      clip_width: 0,
      clip_height: 0,
      image_width: 0,
      image_height: 0,
      image_mode: "future-image-mode",
      image_anchor: "future-anchor",
      image_allow_upscale: false,
      image_background: "",
      image_quality: 0,
      pdf_paper_format: "future-paper",
      pdf_landscape: false,
      pdf_print_background: false,
      pdf_margin: "",
      pdf_margin_top: "",
      pdf_margin_right: "",
      pdf_margin_bottom: "",
      pdf_margin_left: "",
      pdf_scale: 0,
      cache: false,
      cache_ttl: 0,
      cache_key: "",
      storage_mode: "future-storage",
      storage_endpoint: "",
      storage_bucket: "",
      storage_region: "",
      storage_object_key: ""
    )

    client.capture("", options)

    assert_equal 1, transport.requests.length
    request = transport.requests.fetch(0)
    assert_equal "POST", request.method
    assert_equal "https://api.screenshotscout.com/v1/capture", request.url
    assert_equal "Bearer access-key", request.headers.fetch("Authorization")
    assert_equal "application/json", request.headers.fetch("Content-Type")
    assert_equal complete_wire_options, JSON.parse(request.body)
  end

  def test_nil_and_empty_repeated_options_are_omitted_without_defaults
    transport = RecordingTransport.new
    options = ScreenshotScout::CaptureOptions.new(
      format: nil,
      cookies: [],
      headers: [],
      hide_selectors: [],
      click_selectors: [],
      click_all_selectors: [],
      inject_css: [],
      inject_js: []
    )

    client(transport).capture("https://example.com", options)

    assert_equal({ "url" => "https://example.com" }, JSON.parse(transport.requests.fetch(0).body))
  end

  def test_get_and_capture_url_preserve_repeated_values_and_credentials_policy
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "query-key")
    options = ScreenshotScout::CaptureOptions.new(
      cookies: ["a=1", "a=1"],
      headers: ["X-Test:one", "X-Test:one"],
      delay: 0,
      full_page: false,
      cache_key: ""
    )

    screenshot_client.capture(
      "https://example.com/a path",
      options,
      method: ScreenshotScout::CaptureHttpMethod::GET
    )
    built = screenshot_client.build_capture_url("https://example.com/a path", options)

    request = transport.requests.fetch(0)
    assert_equal "GET", request.method
    assert_nil request.body
    refute request.headers.key?("Content-Type")
    assert_equal "Bearer query-key", request.headers.fetch("Authorization")
    assert_equal(
      "url=https%3A%2F%2Fexample.com%2Fa+path&cookies=a%3D1&cookies=a%3D1&" \
      "headers=X-Test%3Aone&headers=X-Test%3Aone&delay=0&full_page=false&cache_key=",
      URI.parse(request.url).query
    )
    refute_includes request.url, "access_key="
    assert_equal(
      "https://api.screenshotscout.com/v1/capture?access_key=query-key&" \
      "url=https%3A%2F%2Fexample.com%2Fa+path&cookies=a%3D1&cookies=a%3D1&" \
      "headers=X-Test%3Aone&headers=X-Test%3Aone&delay=0&full_page=false&cache_key=",
      built
    )
    assert_equal 1, transport.requests.length
  end

  def test_signatures_match_the_api_for_get_post_and_generated_urls
    transport = RecordingTransport.new(TestResponses.json)
    screenshot_client = client(
      transport,
      access_key: "ak_test",
      secret_key: "sk_test"
    )
    options = ScreenshotScout::CaptureOptions.new(
      response_type: ScreenshotScout::CaptureResponseType::JSON,
      full_page: false,
      delay: 0,
      headers: ["X-Test:one", "X-Test:two"]
    )
    target = "https://example.com/a b?x=1&y=2"
    expected = "0c4928ba691575903f27b911b8ea1a536604ca070d60d886e10c127c05e236fc"

    screenshot_client.capture(target, options, method: ScreenshotScout::CaptureHttpMethod::GET)
    screenshot_client.capture(target, options)
    built = screenshot_client.build_capture_url(target, options)

    assert_equal expected, query_values(transport.requests.fetch(0).url, "signature").first
    assert_equal expected, JSON.parse(transport.requests.fetch(1).body).fetch("signature")
    assert_equal expected, query_values(built, "signature").first
    assert_equal "ak_test", query_values(built, "access_key").first
    refute_includes built, "sk_test"
    refute_includes transport.requests.fetch(0).url, "access_key="
    refute JSON.parse(transport.requests.fetch(1).body).key?("access_key")
  end

  def test_form_encoding_matches_the_documented_whatwg_rules
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")
    options = ScreenshotScout::CaptureOptions.new(
      format: "a*b~c",
      hide_selectors: ["div > *", "~"],
      selector: "*~"
    )

    screenshot_client.capture(
      "https://example.com/~ *",
      options,
      method: ScreenshotScout::CaptureHttpMethod::GET
    )

    query = URI.parse(transport.requests.fetch(0).url).query
    assert_includes query, "url=https%3A%2F%2Fexample.com%2F%7E+*"
    assert_includes query, "format=a*b%7Ec"
    assert_includes query, "hide_selectors=div+%3E+*"
    assert_includes query, "hide_selectors=%7E"
    assert_includes query, "selector=*%7E"
  end

  def test_floating_point_options_use_ecmascript_formatting
    cases = [
      [0.0, "0"],
      [-0.0, "0"],
      [2.0, "2"],
      [1.25, "1.25"],
      [0.000001, "0.000001"],
      [0.0000001, "1e-7"],
      [10_000_000.0, "10000000"],
      [100_000_000_000_000_000_000.0, "100000000000000000000"],
      [1e21, "1e+21"],
      [-1.2e-7, "-1.2e-7"],
      [1_000_000_000_000_000_128.0, "1000000000000000100"],
      [5e-324, "5e-324"],
      [Float::MAX, "1.7976931348623157e+308"]
    ]

    cases.each do |value, expected|
      transport = RecordingTransport.new
      screenshot_client = client(transport)
      options = ScreenshotScout::CaptureOptions.new(pdf_scale: value)
      screenshot_client.capture(
        "https://example.com",
        options,
        method: ScreenshotScout::CaptureHttpMethod::GET
      )
      screenshot_client.capture("https://example.com", options)

      assert_equal expected, query_values(transport.requests.fetch(0).url, "pdf_scale").first
      parsed_value = JSON.parse(transport.requests.fetch(1).body).fetch("pdf_scale")
      assert_equal value, parsed_value.to_f
      assert_includes transport.requests.fetch(1).body, %("pdf_scale":#{expected})
    end
  end

  def test_signed_post_with_a_whole_float_matches_api_canonicalization
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")
    options = ScreenshotScout::CaptureOptions.new(pdf_scale: 2.0)

    screenshot_client.capture("https://example.com", options)

    assert_equal(
      '{"url":"https://example.com","pdf_scale":2,' \
      '"signature":"9455e37a8893f7a2e43d5bdf8203986139f66f768bd7ccebb8c8df80604a9683"}',
      transport.requests.fetch(0).body
    )
  end

  def test_unsafe_values_fail_before_calling_the_transport
    transport = RecordingTransport.new
    screenshot_client = client(transport)
    cases = [
      [123, nil, nil],
      ["https://example.com", Object.new, nil],
      ["https://example.com", ScreenshotScout::CaptureOptions.new(format: {}), nil],
      ["https://example.com", ScreenshotScout::CaptureOptions.new(pdf_scale: Float::INFINITY), nil],
      ["https://example.com", ScreenshotScout::CaptureOptions.new(headers: ["X-Test:one", 1]), nil],
      ["https://example.com", ScreenshotScout::CaptureOptions.new(format: "\xFF".b), nil],
      ["https://example.com", ScreenshotScout::CaptureOptions.new(timeout: 9_007_199_254_740_993), nil],
      ["https://example.com", nil, "get"]
    ]

    cases.each do |url, options, method|
      assert_raises(ScreenshotScout::SerializationError) do
        if method.nil?
          screenshot_client.capture(url, options)
        else
          screenshot_client.capture(url, options, method: method)
        end
      end
    end

    assert_raises(ScreenshotScout::SerializationError) do
      ScreenshotScout::CaptureOptions.new(unknown_option: true)
    end
    assert_empty transport.requests
  end

  private

  def client(transport, access_key: "key", secret_key: nil)
    ScreenshotScout::Client.new(
      access_key: access_key,
      secret_key: secret_key,
      transport: transport
    )
  end

  def query_values(url, name)
    URI.decode_www_form(URI.parse(url).query).filter_map { |key, value| value if key == name }
  end

  def complete_wire_options
    {
      "url" => "",
      "format" => "future-format",
      "response_type" => "future-response",
      "country" => "",
      "proxy" => "",
      "geolocation_latitude" => 0,
      "geolocation_longitude" => 0,
      "geolocation_accuracy" => 0,
      "cookies" => ["session=a", "session=a", ""],
      "headers" => ["X-Test:one", "X-Test:one", ""],
      "timeout" => 0,
      "wait_until" => "future-wait-state",
      "navigation_timeout" => 0,
      "delay" => 0,
      "device" => "",
      "device_viewport_width" => 0,
      "device_viewport_height" => 0,
      "device_scale_factor" => 0,
      "device_is_mobile" => false,
      "device_has_touch" => false,
      "device_user_agent" => "",
      "timezone" => "",
      "media_type" => "future-media",
      "color_scheme" => "future-scheme",
      "reduced_motion" => false,
      "full_page" => false,
      "full_page_pre_scroll" => false,
      "full_page_pre_scroll_step" => 0,
      "full_page_pre_scroll_step_delay" => 0,
      "full_page_max_height" => 0,
      "block_cookie_banners" => false,
      "block_ads" => false,
      "block_chat_widgets" => false,
      "hide_selectors" => [".same", ".same", ""],
      "click_selectors" => ["#first", "#first", ""],
      "click_all_selectors" => [".all", ".all", ""],
      "inject_css" => ["", "body { color: red; }"],
      "inject_js" => ["", "document.title = 'x';"],
      "bypass_csp" => false,
      "selector" => "",
      "clip_x" => 0,
      "clip_y" => 0,
      "clip_width" => 0,
      "clip_height" => 0,
      "image_width" => 0,
      "image_height" => 0,
      "image_mode" => "future-image-mode",
      "image_anchor" => "future-anchor",
      "image_allow_upscale" => false,
      "image_background" => "",
      "image_quality" => 0,
      "pdf_paper_format" => "future-paper",
      "pdf_landscape" => false,
      "pdf_print_background" => false,
      "pdf_margin" => "",
      "pdf_margin_top" => "",
      "pdf_margin_right" => "",
      "pdf_margin_bottom" => "",
      "pdf_margin_left" => "",
      "pdf_scale" => 0,
      "cache" => false,
      "cache_ttl" => 0,
      "cache_key" => "",
      "storage_mode" => "future-storage",
      "storage_endpoint" => "",
      "storage_bucket" => "",
      "storage_region" => "",
      "storage_object_key" => ""
    }
  end
end
