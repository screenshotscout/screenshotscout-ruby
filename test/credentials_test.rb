# frozen_string_literal: true

require_relative "test_helper"

class CredentialsTest < Minitest::Test
  ACCESS = "SCREENSHOTSCOUT_ACCESS_KEY"
  SECRET = "SCREENSHOTSCOUT_SECRET_KEY"
  BASE_URL = "SCREENSHOTSCOUT_BASE_URL"

  def test_with_no_keys_passed_both_variables_are_read_once
    environment, names = recording_environment(ACCESS => "ak", SECRET => "sk")

    assert_equal resolved("ak", "sk", from_environment: true), resolve(nil, nil, environment)
    assert_equal [ACCESS, SECRET], names
  end

  def test_an_unset_or_empty_secret_variable_means_no_secret_key
    [{ ACCESS => "ak" }, { ACCESS => "ak", SECRET => "" }].each do |environment|
      assert_equal resolved("ak", nil, from_environment: true), resolve(nil, nil, environment)
    end
  end

  def test_a_missing_or_empty_access_key_variable_is_an_error_that_names_it
    [{}, { ACCESS => "" }, { SECRET => "sk" }].each do |environment|
      error = assert_raises(ScreenshotScout::ConfigurationError) { resolve(nil, nil, environment) }

      assert_equal(
        "A non-blank Screenshot Scout access key is required. Pass one, or set SCREENSHOTSCOUT_ACCESS_KEY.",
        error.message
      )
    end
  end

  def test_a_whitespace_only_variable_is_an_error_that_names_it
    [
      [{ ACCESS => "  " }, "SCREENSHOTSCOUT_ACCESS_KEY is set but blank."],
      [{ ACCESS => "ak", SECRET => " \t" }, "SCREENSHOTSCOUT_SECRET_KEY is set but blank."]
    ].each do |environment, message|
      error = assert_raises(ScreenshotScout::ConfigurationError) { resolve(nil, nil, environment) }

      assert_equal message, error.message
    end
  end

  def test_passing_either_key_means_no_variable_is_read
    environment, names = recording_environment(ACCESS => "ak_env", SECRET => "sk_env")

    assert_equal resolved("ak", nil, from_environment: false), resolve("ak", nil, environment)
    assert_equal resolved(nil, "sk", from_environment: false), resolve(nil, "sk", environment)
    assert_equal resolved("", nil, from_environment: false), resolve("", nil, environment)
    assert_empty names
  end

  def test_a_base_url_is_used_as_given_without_trailing_slashes_and_no_variable_is_read
    [
      ["http://localhost:8787", "http://localhost:8787/v1/capture"],
      ["http://localhost:8787/", "http://localhost:8787/v1/capture"],
      ["https://proxy.example.com/screenshotscout//", "https://proxy.example.com/screenshotscout/v1/capture"],
      ["https://proxy.example.com/a%20b", "https://proxy.example.com/a%20b/v1/capture"]
    ].each do |base_url, capture_endpoint|
      environment, names = recording_environment(BASE_URL => "http://env.example")

      assert_equal resolved_base_url(capture_endpoint, from_environment: false), resolve_base_url(base_url, environment)
      assert_empty names
    end
  end

  def test_without_a_base_url_the_base_url_variable_is_read
    [nil, ""].each do |base_url|
      environment, names = recording_environment(BASE_URL => "http://localhost:8787/")

      assert_equal(
        resolved_base_url("http://localhost:8787/v1/capture", from_environment: true),
        resolve_base_url(base_url, environment)
      )
      assert_equal [BASE_URL], names
    end
  end

  def test_an_unset_or_empty_base_url_variable_means_the_screenshot_scout_api
    [{}, { BASE_URL => "" }].each do |environment|
      assert_equal(
        resolved_base_url("https://api.screenshotscout.com/v1/capture", from_environment: false),
        resolve_base_url(nil, environment)
      )
    end
  end

  def test_a_blank_base_url_variable_or_a_base_url_that_is_not_a_string_is_an_error
    [
      [nil, { BASE_URL => "  " }, "SCREENSHOTSCOUT_BASE_URL is set but blank."],
      [1, {}, "The Screenshot Scout base URL must be a string when provided."]
    ].each do |base_url, environment, message|
      error = assert_raises(ScreenshotScout::ConfigurationError) { resolve_base_url(base_url, environment) }

      assert_equal message, error.message
    end
  end

  private

  def resolve(access_key, secret_key, environment)
    ScreenshotScout::Internal::Credentials.resolve(access_key, secret_key, environment: environment)
  end

  def resolved(access_key, secret_key, from_environment:)
    ScreenshotScout::Internal::Credentials::Resolved.new(
      access_key: access_key,
      secret_key: secret_key,
      from_environment: from_environment
    )
  end

  def resolve_base_url(base_url, environment)
    ScreenshotScout::Internal::Credentials.resolve_base_url(base_url, environment: environment)
  end

  def resolved_base_url(capture_endpoint, from_environment:)
    ScreenshotScout::Internal::Credentials::ResolvedBaseUrl.new(
      capture_endpoint: capture_endpoint,
      from_environment: from_environment
    )
  end

  # A lookup that returns values like ENV does and records each name it's asked for.
  def recording_environment(values)
    names = []
    lookup = lambda do |name|
      names << name
      values[name]
    end
    [lookup, names]
  end
end
