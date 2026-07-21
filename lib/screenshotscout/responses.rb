# frozen_string_literal: true

module ScreenshotScout
  # Exact buffered HTTP response data retained on successes and API failures.
  class RawResponse
    attr_reader :status, :reason_phrase, :headers, :content_type, :body

    def initialize(status:, reason_phrase:, headers:, content_type:, body:)
      @status = status
      @reason_phrase = reason_phrase.dup.freeze
      @headers = copy_headers(headers)
      @normalized_headers = @headers.to_h do |name, values|
        [name.downcase, values]
      end.freeze
      @content_type = content_type&.dup&.freeze
      @body = body.dup.freeze
      freeze
    end

    def header(name)
      @normalized_headers.fetch(name.downcase, EMPTY_HEADER_VALUES)
    end

    EMPTY_HEADER_VALUES = [].freeze
    private_constant :EMPTY_HEADER_VALUES

    private

    def copy_headers(headers)
      headers.to_h do |name, values|
        copied_values = Array(values).map { |value| value.to_s.dup.freeze }.freeze
        [name.to_s.dup.freeze, copied_values]
      end.freeze
    end
  end

  # Shared response base that exposes the exact buffered HTTP response.
  class CaptureResponse
    attr_reader :raw_response

    def initialize(raw_response:)
      @raw_response = raw_response
    end
  end

  # Successful binary capture, including response metadata and image/PDF bytes.
  class BinaryCaptureResponse < CaptureResponse
    attr_reader :bytes, :screenshot_url, :screenshot_url_expires_at, :cache_status

    def initialize(raw_response:, screenshot_url:, screenshot_url_expires_at:, cache_status:)
      super(raw_response: raw_response)
      @bytes = raw_response.body
      @screenshot_url = screenshot_url
      @screenshot_url_expires_at = screenshot_url_expires_at
      @cache_status = cache_status
      freeze
    end
  end

  # Structured capture result returned when response_type is json.
  class CaptureResult
    attr_reader :screenshot_url, :screenshot_url_expires_at, :cache_status, :additional_fields

    def initialize(screenshot_url:, screenshot_url_expires_at:, cache_status:, additional_fields:)
      @screenshot_url = screenshot_url
      @screenshot_url_expires_at = screenshot_url_expires_at
      @cache_status = cache_status
      @additional_fields = additional_fields.freeze
      freeze
    end
  end

  # Successful JSON capture response and its structured result.
  class JsonCaptureResponse < CaptureResponse
    attr_reader :result

    def initialize(result:, raw_response:)
      super(raw_response: raw_response)
      @result = result
      freeze
    end
  end
end
