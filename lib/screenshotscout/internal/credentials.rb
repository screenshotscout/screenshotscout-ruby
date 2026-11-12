# frozen_string_literal: true

module ScreenshotScout
  module Internal
    # Picks the keys a client uses: the keys passed to it, or else the environment variables.
    module Credentials
      ACCESS_KEY_VARIABLE = "SCREENSHOTSCOUT_ACCESS_KEY"
      SECRET_KEY_VARIABLE = "SCREENSHOTSCOUT_SECRET_KEY"

      # The keys to validate, and whether they were read from the environment.
      Resolved = Data.define(:access_key, :secret_key, :from_environment)

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
