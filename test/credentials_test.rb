# frozen_string_literal: true

require_relative "test_helper"

class CredentialsTest < Minitest::Test
  ACCESS = "SCREENSHOTSCOUT_ACCESS_KEY"
  SECRET = "SCREENSHOTSCOUT_SECRET_KEY"

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
