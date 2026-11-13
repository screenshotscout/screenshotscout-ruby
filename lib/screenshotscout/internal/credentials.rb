# frozen_string_literal: true

module ScreenshotScout
  module Internal
    # Picks the keys and the base URL a client uses: the values passed to it, or else the environment variables.
    module Credentials
      ACCESS_KEY_VARIABLE = "SCREENSHOTSCOUT_ACCESS_KEY"
      SECRET_KEY_VARIABLE = "SCREENSHOTSCOUT_SECRET_KEY"
      BASE_URL_VARIABLE = "SCREENSHOTSCOUT_BASE_URL"
      DEFAULT_BASE_URL = "https://api.screenshotscout.com"
      CAPTURE_PATH = "/v1/capture"

      # The keys to validate, and whether they were read from the environment.
      Resolved = Data.define(:access_key, :secret_key, :from_environment)

      # The URL captures are sent to and capture URLs are built on, and whether the base URL was read from the
      # environment.
      ResolvedBaseUrl = Data.define(:capture_endpoint, :from_environment)

      module_function

      # Keys passed to the client always win: if either one is passed, neither variable is read. Only when
      # both are nil are both read, as environment[name], which ENV, a Hash and a lambda all support.
      def resolve(access_key, secret_key, environment:)
        unless access_key.nil? && secret_key.nil?
          return Resolved.new(access_key: access_key, secret_key: secret_key, from_environment: false)
        end

        environment_access_key = read_variable(environment, ACCESS_KEY_VARIABLE)
        environment_secret_key = read_variable(environment, SECRET_KEY_VARIABLE)
        if environment_access_key.nil?
          raise ConfigurationError,
                "A non-blank Screenshot Scout access key is required. Pass one, or set #{ACCESS_KEY_VARIABLE}."
        end

        Resolved.new(access_key: environment_access_key, secret_key: environment_secret_key, from_environment: true)
      end

      # A base URL passed to the client wins. Without one, the variable is read, whether or not keys were passed,
      # and without that the production API is used. The base URL is used as given: only trailing slashes are
      # removed before the capture path is appended.
      def resolve_base_url(base_url, environment:)
        unless base_url.nil? || base_url.is_a?(String)
          raise ConfigurationError, "The Screenshot Scout base URL must be a string when provided."
        end
        unless base_url.nil? || base_url.empty?
          return ResolvedBaseUrl.new(capture_endpoint: append_capture_path(base_url), from_environment: false)
        end

        environment_base_url = read_variable(environment, BASE_URL_VARIABLE)
        if environment_base_url.nil?
          ResolvedBaseUrl.new(capture_endpoint: append_capture_path(DEFAULT_BASE_URL), from_environment: false)
        else
          ResolvedBaseUrl.new(capture_endpoint: append_capture_path(environment_base_url), from_environment: true)
        end
      end

      # Uses no regular expression, which would raise ArgumentError for text that isn't valid UTF-8.
      def append_capture_path(base_url)
        base_url = base_url.delete_suffix("/") while base_url.end_with?("/")
        base_url + CAPTURE_PATH
      end
      private_class_method :append_capture_path

      # Returns nil for a variable that is unset or empty.
      def read_variable(environment, name)
        value = environment[name]
        return nil if value.nil? || value.empty?
        raise ConfigurationError, "#{name} is set but blank." if value.strip.empty?

        value
      end
      private_class_method :read_variable
    end
  end
end
