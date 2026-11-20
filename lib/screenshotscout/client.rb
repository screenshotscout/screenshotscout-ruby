# frozen_string_literal: true

require "openssl"

module ScreenshotScout
  # Reusable blocking client for the inline Screenshot Scout capture operation.
  class Client
    ACCESS_KEY_PATTERN = %r{\A[A-Za-z0-9\-._~+/]+=*\z}

    # Creates a client. When no key is passed, the client reads SCREENSHOTSCOUT_ACCESS_KEY and, if it's set,
    # SCREENSHOTSCOUT_SECRET_KEY. Passing either key means neither variable is read. Pass base_url to send
    # requests to another server, such as your own proxy or a mock server: captures go to that URL plus
    # /v1/capture, and build_capture_url builds URLs on it. When no base URL is passed, the client reads
    # SCREENSHOTSCOUT_BASE_URL, and without it uses the Screenshot Scout API.
    def initialize(access_key: nil, secret_key: nil, base_url: nil, transport: nil)
      credentials = Internal::Credentials.resolve(access_key, secret_key, environment: ENV)
      validate_access_key(credentials.access_key)
      validate_secret_key(credentials.secret_key)
      validate_transport(transport)
      endpoint = Internal::Credentials.resolve_base_url(base_url, environment: ENV)

      @access_key = credentials.access_key.dup.freeze
      @secret_key = credentials.secret_key&.dup&.freeze
      @secret_key_from_environment = credentials.from_environment && !@secret_key.nil?
      @capture_endpoint = endpoint.capture_endpoint
      @base_url_from_environment = endpoint.from_environment
      @transport = transport || NetHttpTransport.new
    end

    # Sends one GET or POST request and waits for the final inline response. The method defaults to POST,
    # or GET when the client has a secret key, because POST requests can't be signed. A client with a secret
    # key signs GET requests and raises ConfigurationError for an explicit POST.
    def capture(url, options = nil, method: nil)
      serialized = Internal::Serializer.serialize(url, options)
      validate_method(method) unless method.nil?
      reject_signed_post(method)
      method ||= @secret_key.nil? ? CaptureHttpMethod::POST : CaptureHttpMethod::GET
      send_capture(serialized, method, options)
    end

    # Captures an HTML document instead of a URL, such as an invoice or a report you generated. Sends the HTML
    # exactly as given, in one POST request, and waits for the final inline response. A binary string, such as the
    # result of File.binread or an HTTP response body, is read as UTF-8. A client with a secret key raises
    # ConfigurationError, because POST requests can't be signed.
    def capture_from_html(html, options = nil)
      serialized = Internal::Serializer.serialize(html, options, target: :html)
      reject_signed_html
      send_capture(serialized, CaptureHttpMethod::POST, options)
    end

    # Builds a sensitive GET capture URL without performing network I/O.
    def build_capture_url(url, options = nil)
      serialized = Internal::Serializer.serialize(url, options)
      signature = create_signature(serialized.pairs)
      pairs = [Internal::WirePair.new(name: "access_key", value: @access_key), *serialized.pairs]
      pairs << Internal::WirePair.new(name: "signature", value: signature) unless signature.nil?
      "#{@capture_endpoint}?#{Internal::Serializer.encode_query(pairs)}"
    end

    # Leaves out the keys, so that printing or logging a client doesn't reveal them.
    def inspect
      "#<#{self.class.name}>"
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

    def reject_signed_post(method)
      return if @secret_key.nil? || method != CaptureHttpMethod::POST

      source = @secret_key_from_environment ? " from #{Internal::Credentials::SECRET_KEY_VARIABLE}" : ""
      raise ConfigurationError,
            "POST requests can't be signed. This client has a secret key#{source}: send this capture with " \
            "method GET, or use a client without a secret key and an API key that doesn't require signed requests."
    end

    def reject_signed_html
      return if @secret_key.nil?

      source = @secret_key_from_environment ? " from #{Internal::Credentials::SECRET_KEY_VARIABLE}" : ""
      raise ConfigurationError,
            "`capture_from_html` sends the HTML in a POST body, which can't be signed. This client has a secret " \
            "key#{source}: use a client without a secret key and an API key that doesn't require signed requests."
    end

    def send_capture(serialized, method, options)
      signature = create_signature(serialized.pairs)
      request = create_request(serialized, method, signature)
      Internal::ResponseDecoder.decode(execute_request(request), options)
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
        url = "#{@capture_endpoint}?#{Internal::Serializer.encode_query(pairs)}"
        TransportRequest.new(method: method, url: url, headers: headers)
      else
        headers["Content-Type"] = "application/json"
        TransportRequest.new(
          method: method,
          url: @capture_endpoint,
          headers: headers,
          body: Internal::JsonCodec.encode_wire_object(serialized.body)
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
      source = @base_url_from_environment ? " The base URL comes from #{Internal::Credentials::BASE_URL_VARIABLE}." : ""
      raise TransportError,
            "Screenshot Scout request failed before a complete HTTP response body was received.#{source}",
            cause: e
    end

    private_constant :ACCESS_KEY_PATTERN
  end
end
