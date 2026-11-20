# frozen_string_literal: true

require "json"

module ScreenshotScout
  module Internal
    # Turns the buffered response to a capture request into the capture response its options ask for, or into an
    # APIError for a non-2xx status.
    module ResponseDecoder
      module_function

      def decode(raw_response, options)
        raise create_api_error(raw_response) unless raw_response.status.between?(200, 299)

        decode_success_response(raw_response, expected_response_kind(options))
      end

      def expected_response_kind(options)
        response_type = options&.response_type
        return :binary if response_type.nil? || response_type == CaptureResponseType::BINARY
        return :json if response_type == CaptureResponseType::JSON

        nil
      end
      private_class_method :expected_response_kind

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
      private_class_method :decode_success_response

      def decode_binary_response(raw_response)
        BinaryCaptureResponse.new(
          raw_response: raw_response,
          screenshot_url: raw_response.header("Screenshot-Scout-Screenshot-URL").first,
          screenshot_url_expires_at: raw_response.header("Screenshot-Scout-Screenshot-URL-Expires-At").first,
          cache_status: raw_response.header("Screenshot-Scout-Cache-Status").first,
          markdown: markdown_media_type?(raw_response.content_type) ? utf8_text(raw_response.body) : nil,
          html: html_media_type?(raw_response.content_type) ? utf8_text(raw_response.body) : nil
        )
      end
      private_class_method :decode_binary_response

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
      private_class_method :decode_json_response

      def parse_json_success(raw_response)
        JsonCodec.parse(raw_response.body)
      rescue JSON::ParserError, EncodingError => e
        raise ResponseDecodingError.new(
          "Screenshot Scout returned a successful JSON response that could not be decoded.",
          raw_response
        ), cause: e
      end
      private_class_method :parse_json_success

      def read_optional_string(object, key, raw_response)
        return nil unless object.key?(key)
        return object[key] if object[key].is_a?(String)

        cause = TypeError.new("Expected \"#{key}\" to be a string.")
        raise ResponseDecodingError.new(
          "Screenshot Scout returned a non-string \"#{key}\" JSON field.",
          raw_response
        ), cause: cause
      end
      private_class_method :read_optional_string

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
      private_class_method :create_api_error

      def try_parse_json(body)
        [true, JsonCodec.parse(body)]
      rescue JSON::ParserError, EncodingError
        [false, nil]
      end
      private_class_method :try_parse_json

      def json_media_type?(content_type)
        return false if content_type.nil?

        media_type = content_type.partition(";").first.strip.downcase
        media_type == "application/json" || media_type.end_with?("+json")
      end
      private_class_method :json_media_type?

      def markdown_media_type?(content_type) = content_type.to_s.partition(";").first.strip.downcase == "text/markdown"
      private_class_method :markdown_media_type?

      def html_media_type?(content_type) = content_type.to_s.partition(";").first.strip.downcase == "text/html"
      private_class_method :html_media_type?

      def utf8_text(bytes) = bytes.dup.force_encoding(Encoding::UTF_8).scrub
      private_class_method :utf8_text
    end
  end
end
