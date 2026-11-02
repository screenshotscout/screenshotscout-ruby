# frozen_string_literal: true

require "net/http"
require "uri"

module ScreenshotScout
  # The request object passed to an injected transport's #call method.
  class TransportRequest
    attr_reader :method, :url, :headers, :body

    def initialize(method:, url:, headers:, body: nil)
      @method = method.dup.freeze
      @url = url.dup.freeze
      @headers = headers.to_h do |name, value|
        [name.to_s.dup.freeze, value.to_s.dup.freeze]
      end.freeze
      @body = body&.dup&.freeze
      freeze
    end
  end

  # Small default adapter. It owns each Net::HTTP session that it opens.
  class NetHttpTransport
    # Longer than the longest capture Screenshot Scout allows (240 seconds). Net::HTTP waits 60.
    READ_TIMEOUT_SECONDS = 300
    private_constant :READ_TIMEOUT_SECONDS

    def call(request)
      uri = URI.parse(request.url)
      net_request = build_request(uri, request)
      response = build_session(uri).start { |session| session.request(net_request) }

      RawResponse.new(
        status: response.code.to_i,
        reason_phrase: response.message.to_s,
        headers: response.to_hash,
        content_type: response["content-type"],
        body: response.body || String.new(encoding: Encoding::BINARY)
      )
    end

    private

    def build_session(uri)
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = READ_TIMEOUT_SECONDS
      http.max_retries = 0
      http
    end

    def build_request(uri, request)
      net_request = case request.method
                    when CaptureHttpMethod::GET
                      Net::HTTP::Get.new(uri)
                    when CaptureHttpMethod::POST
                      Net::HTTP::Post.new(uri)
                    else
                      raise ArgumentError, "Unsupported HTTP method #{request.method.inspect}."
                    end

      request.headers.each { |name, value| net_request[name] = value }
      net_request.body = request.body unless request.body.nil?
      net_request
    end
  end
end
