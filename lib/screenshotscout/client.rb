# frozen_string_literal: true

require "openssl"

module ScreenshotScout
  # Reusable blocking client for the inline Screenshot Scout capture operation.
  class Client
    CAPTURE_ENDPOINT = "https://api.screenshotscout.com/v1/capture"
    ACCESS_KEY_PATTERN = %r{\A[A-Za-z0-9\-._~+/]+=*\z}
    MISSING_ACCESS_KEY = Object.new.freeze

    def initialize(access_key: MISSING_ACCESS_KEY, secret_key: nil, transport: nil)
      validate_access_key(access_key)
      validate_secret_key(secret_key)
      validate_transport(transport)

      @access_key = access_key.dup.freeze
      @secret_key = secret_key&.dup&.freeze
      @transport = transport || NetHttpTransport.new
    end

    # Sends one GET or POST request and waits for the final inline response.
    def capture(url, options = nil, method: CaptureHttpMethod::POST)
      serialized = Internal::Serializer.serialize(url, options)
      validate_method(method)
      expected_kind = expected_response_kind(options)
      signature = create_signature(serialized.pairs)
      request = create_request(serialized, method, signature)
      raw_response = execute_request(request)

      raise create_api_error(raw_response) unless raw_response.status.between?(200, 299)

      decode_success_response(raw_response, expected_kind)
    end

    # Builds a sensitive GET capture URL without performing network I/O.
    def build_capture_url(url, options = nil)
      serialized = Internal::Serializer.serialize(url, options)
      signature = create_signature(serialized.pairs)
      pairs = [Internal::WirePair.new(name: "access_key", value: @access_key), *serialized.pairs]
      pairs << Internal::WirePair.new(name: "signature", value: signature) unless signature.nil?
      "#{CAPTURE_ENDPOINT}?#{Internal::Serializer.encode_query(pairs)}"
    end

    private

    def validate_access_key(access_key)
      unless access_key.is_a?(String) && !access_key.strip.empty?
        raise ConfigurationError, "A non-blank Screenshot Scout access key is required."
      end
      return if ACCESS_KEY_PATTERN.match?(access_key)

      raise ConfigurationError, "The Screenshot Scout access key is not a valid Bearer credential."
    end

    def validate_secret_key(secret_key)
      return if secret_key.nil?
      return if secret_key.is_a?(String) && !secret_key.strip.empty?

      raise ConfigurationError, "The Screenshot Scout secret key must be a non-blank string when provided."
    end

    def validate_transport(transport)
      return if transport.nil? || transport.respond_to?(:call)

      raise ConfigurationError, "The Screenshot Scout transport must respond to #call."
    end

    def validate_method(method)
      return if [CaptureHttpMethod::GET, CaptureHttpMethod::POST].include?(method)

      raise SerializationError.new(
        "The capture method must be CaptureHttpMethod::GET or CaptureHttpMethod::POST.",
        option: :method
      )
    end

    def create_signature(pairs)
      return nil if @secret_key.nil?

      canonical_query = Internal::Serializer.build_canonical_query(pairs, @access_key)
      OpenSSL::HMAC.hexdigest("SHA256", @secret_key, canonical_query)
    rescue Error
      raise
    rescue StandardError => e
      raise SerializationError.new("The capture request could not be signed."), cause: e
    end

    def create_request(serialized, method, signature)
      headers = { "Authorization" => "Bearer #{@access_key}" }
      if method == CaptureHttpMethod::GET
        pairs = serialized.pairs.dup
        pairs << Internal::WirePair.new(name: "signature", value: signature) unless signature.nil?
        url = "#{CAPTURE_ENDPOINT}?#{Internal::Serializer.encode_query(pairs)}"
        TransportRequest.new(method: method, url: url, headers: headers)
      else
        body = serialized.body.dup
        body["signature"] = signature unless signature.nil?
        headers["Content-Type"] = "application/json"
        TransportRequest.new(
          method: method,
          url: CAPTURE_ENDPOINT,
          headers: headers,
          body: Internal::JsonCodec.encode_wire_object(body)
        )
      end
    rescue Error
      raise
    rescue StandardError => e
      raise SerializationError.new("The Screenshot Scout HTTP request could not be constructed."), cause: e
    end

    def execute_request(request)
      raw_response = @transport.call(request)
      return raw_response if raw_response.is_a?(RawResponse)

      raise TypeError, "The Screenshot Scout transport must return ScreenshotScout::RawResponse."
    rescue Error
      raise
    rescue StandardError => e
      raise TransportError, "Screenshot Scout request failed before a complete HTTP response body was received.",
            cause: e
    end

    def expected_response_kind(options)
      response_type = options&.response_type
      return :binary if response_type.nil? || response_type == CaptureResponseType::BINARY
      return :json if response_type == CaptureResponseType::JSON

      nil
    end

    def decode_success_response(raw_response, expected_kind)
      actual_kind = json_media_type?(raw_response.content_type) ? :json : :binary
      if !expected_kind.nil? && actual_kind != expected_kind
        message = "Screenshot Scout returned a successful #{actual_kind} response " \
                  "when #{expected_kind} was requested."
        cause = TypeError.new("Expected a #{expected_kind} response but received #{actual_kind}.")
        raise ResponseDecodingError.new(message, raw_response), cause: cause
      end

      actual_kind == :json ? decode_json_response(raw_response) : decode_binary_response(raw_response)
    end

    def decode_binary_response(raw_response)
      BinaryCaptureResponse.new(
        raw_response: raw_response,
        screenshot_url: raw_response.header("Screenshot-Scout-Screenshot-URL").first,
        screenshot_url_expires_at: raw_response.header("Screenshot-Scout-Screenshot-URL-Expires-At").first,
        cache_status: raw_response.header("Screenshot-Scout-Cache-Status").first
      )
    end

    def decode_json_response(raw_response)
      value = parse_json_success(raw_response)
      unless value.is_a?(Hash)
        cause = TypeError.new("Expected a JSON object.")
        raise ResponseDecodingError.new(
          "Screenshot Scout returned a successful JSON response that was not an object.",
          raw_response
        ), cause: cause
      end

      screenshot_url = read_optional_string(value, "screenshot_url", raw_response)
      expires_at = read_optional_string(value, "screenshot_url_expires_at", raw_response)
      cache_status = read_optional_string(value, "cache_status", raw_response)
      additional_fields = value.except("screenshot_url", "screenshot_url_expires_at", "cache_status")
      result = CaptureResult.new(
        screenshot_url: screenshot_url,
        screenshot_url_expires_at: expires_at,
        cache_status: cache_status,
        additional_fields: additional_fields
      )
      JsonCaptureResponse.new(result: result, raw_response: raw_response)
    end

    def parse_json_success(raw_response)
      Internal::JsonCodec.parse(raw_response.body)
    rescue JSON::ParserError, EncodingError => e
      raise ResponseDecodingError.new(
        "Screenshot Scout returned a successful JSON response that could not be decoded.",
        raw_response
      ), cause: e
    end

    def read_optional_string(object, key, raw_response)
      return nil unless object.key?(key)
      return object[key] if object[key].is_a?(String)

      cause = TypeError.new("Expected \"#{key}\" to be a string.")
      raise ResponseDecodingError.new(
        "Screenshot Scout returned a non-string \"#{key}\" JSON field.",
        raw_response
      ), cause: cause
    end

    def create_api_error(raw_response)
      available, response_body = try_parse_json(raw_response.body)
      object = response_body if response_body.is_a?(Hash)
      error_code = object["error_code"] if object&.fetch("error_code", nil).is_a?(String)
      error_message = object["error_message"] if object&.fetch("error_message", nil).is_a?(String)
      errors = object["errors"] if object&.fetch("errors", nil).is_a?(Array)

      APIError.new(
        raw_response: raw_response,
        response_body_available: available,
        response_body: response_body,
        error_code: error_code,
        error_message: error_message,
        errors: errors
      )
    end

    def try_parse_json(body)
      [true, Internal::JsonCodec.parse(body)]
    rescue JSON::ParserError, EncodingError
      [false, nil]
    end

    def json_media_type?(content_type)
      return false if content_type.nil?

      media_type = content_type.split(";", 2).first.strip.downcase
      media_type == "application/json" || media_type.end_with?("+json")
    end

    private_constant :CAPTURE_ENDPOINT, :ACCESS_KEY_PATTERN, :MISSING_ACCESS_KEY
  end
end
