# frozen_string_literal: true

require_relative "test_helper"

class CaptureSerializationTest < Minitest::Test
  include EnvironmentHelper

  # The request in test_signatures_match_the_api_for_get_and_generated_urls, signed with ak_test and sk_test.
  SIGNED_TARGET = "https://example.com/a b?x=1&y=2"
  SIGNED_SIGNATURE = "6419f2ac8c0440f1e341b547630606c9dc74dacfbb2df8e122fc9ae26831d893"

  def test_configuration_validates_credentials_and_transport
    assert_raises(ScreenshotScout::ConfigurationError) { ScreenshotScout::Client.new(access_key: 123) }
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

  def test_capture_option_names_match_serializer_wire_names
    attribute_names = ScreenshotScout::CaptureOptions.const_get(:ATTRIBUTE_NAMES, false)
    wire_names = ScreenshotScout::Internal::Serializer.const_get(:WIRE_NAMES, false)

    assert_equal wire_names.keys, attribute_names
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
      pdf_page_ranges: "",
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

  def test_explicit_nil_method_uses_the_post_default_without_a_secret_key
    transport = RecordingTransport.new

    client(transport).capture("https://example.com", method: nil)

    request = transport.requests.fetch(0)
    assert_equal ScreenshotScout::CaptureHttpMethod::POST, request.method
    assert_equal({ "url" => "https://example.com" }, JSON.parse(request.body))
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
      "url=https%3A%2F%2Fexample.com%2Fa%20path&cookies=a%3D1&cookies=a%3D1&" \
      "headers=X-Test%3Aone&headers=X-Test%3Aone&delay=0&full_page=false&cache_key=",
      URI.parse(request.url).query
    )
    refute_includes request.url, "access_key="
    assert_equal(
      "https://api.screenshotscout.com/v1/capture?access_key=query-key&" \
      "url=https%3A%2F%2Fexample.com%2Fa%20path&cookies=a%3D1&cookies=a%3D1&" \
      "headers=X-Test%3Aone&headers=X-Test%3Aone&delay=0&full_page=false&cache_key=",
      built
    )
    assert_equal 1, transport.requests.length
  end

  def test_signatures_match_the_api_for_get_and_generated_urls
    transport = RecordingTransport.new(TestResponses.json)
    screenshot_client = client(
      transport,
      access_key: "ak_test",
      secret_key: "sk_test"
    )

    screenshot_client.capture(SIGNED_TARGET, signed_options, method: ScreenshotScout::CaptureHttpMethod::GET)
    built = screenshot_client.build_capture_url(SIGNED_TARGET, signed_options)

    assert_equal 1, transport.requests.length
    assert_equal SIGNED_SIGNATURE, query_values(transport.requests.fetch(0).url, "signature").first
    assert_equal SIGNED_SIGNATURE, query_values(built, "signature").first
    assert_equal "ak_test", query_values(built, "access_key").first
    refute_includes built, "sk_test"
    refute_includes transport.requests.fetch(0).url, "access_key="
  end

  def test_signed_text_and_signatures_match_the_shared_vectors
    path = File.expand_path("fixtures/signing-vectors.json", __dir__)
    vectors = JSON.parse(File.read(path, encoding: "UTF-8")).fetch("vectors")

    refute_empty vectors
    vectors.each do |vector|
      pairs = vector.fetch("params").map do |name, value|
        ScreenshotScout::Internal::WirePair.new(name: name, value: value)
      end
      signed_text = ScreenshotScout::Internal::Serializer.build_canonical_query(pairs, vector.fetch("access_key"))
      signature = OpenSSL::HMAC.hexdigest("SHA256", vector.fetch("secret_key"), signed_text)

      assert_equal vector.fetch("signed_text"), signed_text, vector.fetch("name")
      assert_equal vector.fetch("signature"), signature, vector.fetch("name")
    end
  end

  def test_query_encoding_follows_rfc3986
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")
    options = ScreenshotScout::CaptureOptions.new(
      format: "a*b~c",
      hide_selectors: ["div > *", "~"],
      selector: "*~",
      cache_key: "!'()+é"
    )

    screenshot_client.capture(
      "https://example.com/~ *",
      options,
      method: ScreenshotScout::CaptureHttpMethod::GET
    )

    query = URI.parse(transport.requests.fetch(0).url).query
    assert_includes query, "url=https%3A%2F%2Fexample.com%2F~%20%2A"
    assert_includes query, "format=a%2Ab~c"
    assert_includes query, "hide_selectors=div%20%3E%20%2A"
    assert_includes query, "hide_selectors=~"
    assert_includes query, "selector=%2A~"
    assert_includes query, "cache_key=%21%27%28%29%2B%C3%A9"
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

  def test_client_with_a_secret_key_refuses_an_explicit_post_before_calling_the_transport
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")

    error = assert_raises(ScreenshotScout::ConfigurationError) do
      screenshot_client.capture("https://example.com", method: ScreenshotScout::CaptureHttpMethod::POST)
    end

    assert_equal(
      "POST requests can't be signed. This client has a secret key: send this capture with method GET, " \
      "or use a client without a secret key and an API key that doesn't require signed requests.",
      error.message
    )
    assert_empty transport.requests
  end

  def test_client_with_a_secret_key_sends_a_signed_get_when_no_method_is_chosen
    [{}, { method: nil }].each do |method_argument|
      transport = RecordingTransport.new(TestResponses.json)
      screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")

      screenshot_client.capture(SIGNED_TARGET, signed_options, **method_argument)

      request = transport.requests.fetch(0)
      assert_equal ScreenshotScout::CaptureHttpMethod::GET, request.method
      assert_nil request.body
      assert_equal SIGNED_SIGNATURE, query_values(request.url, "signature").first
    end
  end

  def test_without_keys_the_client_reads_both_environment_variables_once
    transport = RecordingTransport.new(TestResponses.json)

    with_env(
      "SCREENSHOTSCOUT_ACCESS_KEY" => "ak_test",
      "SCREENSHOTSCOUT_SECRET_KEY" => "sk_test"
    ) do
      screenshot_client = ScreenshotScout::Client.new(transport: transport)
      ENV["SCREENSHOTSCOUT_ACCESS_KEY"] = "changed"
      ENV["SCREENSHOTSCOUT_SECRET_KEY"] = "changed"

      screenshot_client.capture(SIGNED_TARGET, signed_options)
    end

    request = transport.requests.fetch(0)
    assert_equal ScreenshotScout::CaptureHttpMethod::GET, request.method
    assert_equal "Bearer ak_test", request.headers.fetch("Authorization")
    assert_equal SIGNED_SIGNATURE, query_values(request.url, "signature").first
  end

  def test_a_client_with_no_arguments_reads_the_environment_and_an_empty_secret_counts_as_unset
    with_env("SCREENSHOTSCOUT_ACCESS_KEY" => "ak_env", "SCREENSHOTSCOUT_SECRET_KEY" => "") do
      url = ScreenshotScout::Client.new.build_capture_url("https://example.com")

      assert_equal ["ak_env"], query_values(url, "access_key")
      assert_empty query_values(url, "signature")
    end
  end

  def test_passing_either_key_means_the_environment_is_never_read
    with_env(
      "SCREENSHOTSCOUT_ACCESS_KEY" => "ak_env",
      "SCREENSHOTSCOUT_SECRET_KEY" => "sk_env"
    ) do
      transport = RecordingTransport.new
      ScreenshotScout::Client.new(access_key: "ak_code", transport: transport).capture("https://example.com")

      request = transport.requests.fetch(0)
      assert_equal ScreenshotScout::CaptureHttpMethod::POST, request.method
      assert_equal "Bearer ak_code", request.headers.fetch("Authorization")

      [{ secret_key: "sk_code" }, { access_key: "" }].each do |keys|
        error = assert_raises(ScreenshotScout::ConfigurationError) { ScreenshotScout::Client.new(**keys) }
        assert_equal "A non-blank Screenshot Scout access key is required.", error.message
      end
    end
  end

  def test_a_missing_access_key_names_the_environment_variable
    error = assert_raises(ScreenshotScout::ConfigurationError) { ScreenshotScout::Client.new }

    assert_equal(
      "A non-blank Screenshot Scout access key is required. Pass one, or set SCREENSHOTSCOUT_ACCESS_KEY.",
      error.message
    )
  end

  def test_an_explicit_post_names_the_variable_a_secret_key_came_from
    transport = RecordingTransport.new

    error = with_env(
      "SCREENSHOTSCOUT_ACCESS_KEY" => "ak_env",
      "SCREENSHOTSCOUT_SECRET_KEY" => "sk_env"
    ) do
      screenshot_client = ScreenshotScout::Client.new(transport: transport)
      assert_raises(ScreenshotScout::ConfigurationError) do
        screenshot_client.capture("https://example.com", method: ScreenshotScout::CaptureHttpMethod::POST)
      end
    end

    assert_equal(
      "POST requests can't be signed. This client has a secret key from SCREENSHOTSCOUT_SECRET_KEY: " \
      "send this capture with method GET, or use a client without a secret key and an API key that " \
      "doesn't require signed requests.",
      error.message
    )
    assert_empty transport.requests
  end

  def test_inspect_and_pp_leave_out_both_keys
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")
    screenshot_client.capture("https://example.com")
    request = transport.requests.fetch(0)

    assert_equal "#<ScreenshotScout::Client>", screenshot_client.inspect
    assert_includes request.inspect, "[FILTERED]"
    [screenshot_client, request].each do |object|
      printed, = capture_io { pp object }

      [object.inspect, printed].each do |output|
        refute_includes output, "ak_test"
        refute_includes output, "sk_test"
      end
    end
  end

  def test_text_that_is_not_valid_utf8_is_rejected_with_the_option_name
    transport = RecordingTransport.new
    screenshot_client = client(transport, access_key: "ak_test", secret_key: "sk_test")
    invalid = "caf\xC3".dup.force_encoding(Encoding::UTF_8)

    url_error = assert_raises(ScreenshotScout::SerializationError) do
      screenshot_client.build_capture_url("https://example.com/#{invalid}")
    end
    option_error = assert_raises(ScreenshotScout::SerializationError) do
      screenshot_client.capture(
        "https://example.com",
        ScreenshotScout::CaptureOptions.new(hide_selectors: [invalid]),
        method: ScreenshotScout::CaptureHttpMethod::GET
      )
    end

    assert_equal :url, url_error.option
    assert_equal "The capture target URL must contain valid UTF-8.", url_error.message
    assert_equal :hide_selectors, option_error.option
    assert_equal "The capture option \"hide_selectors\" must contain valid UTF-8.", option_error.message
    assert_empty transport.requests
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

  def signed_options
    ScreenshotScout::CaptureOptions.new(
      response_type: ScreenshotScout::CaptureResponseType::JSON,
      full_page: false,
      delay: 0,
      headers: ["X-Test:one", "X-Test:two"]
    )
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
      "pdf_page_ranges" => "",
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
