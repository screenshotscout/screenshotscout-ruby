# frozen_string_literal: true

module ScreenshotScout
  # Base class for every exception raised by the SDK.
  class Error < StandardError; end

  # Raised when client credentials or capture-call controls are unusable.
  class ConfigurationError < Error; end

  # Raised when a capture option cannot be represented safely on the wire.
  class SerializationError < Error
    attr_reader :option

    def initialize(message, option: nil)
      super(message)
      @option = option
    end
  end

  # Raised when the configured transport cannot complete an HTTP exchange.
  class TransportError < Error; end

  # Raised for every non-2xx response returned by the Screenshot Scout API.
  class APIError < Error
    attr_reader :status, :error_code, :error_message, :errors, :response_body, :raw_response

    def initialize(
      raw_response:,
      response_body_available:,
      response_body: nil,
      error_code: nil,
      error_message: nil,
      errors: nil
    )
      super(error_message || "Screenshot Scout API request failed with status #{raw_response.status}.")
      @status = raw_response.status
      @error_code = error_code
      @error_message = error_message
      @errors = errors
      @response_body_available = response_body_available
      @response_body = response_body
      @raw_response = raw_response
    end

    def response_body?
      @response_body_available
    end
  end

  # Raised when a successful response cannot be decoded as its expected type.
  class ResponseDecodingError < Error
    attr_reader :raw_response

    def initialize(message, raw_response)
      super(message)
      @raw_response = raw_response
    end
  end
end
