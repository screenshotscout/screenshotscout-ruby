# frozen_string_literal: true

require "json"

module ScreenshotScout
  module Internal
    # Encodes already-validated capture values using API-compatible JSON numbers.
    module JsonCodec
      module_function

      def encode_wire_object(object)
        members = object.map do |name, value|
          "#{JSON.generate(name)}:#{encode_wire_value(value)}"
        end
        "{#{members.join(',')}}"
      end

      def parse(body)
        JSON.parse(body, create_additions: false)
      end

      def encode_wire_value(value)
        case value
        when String
          JSON.generate(value)
        when Integer
          EcmaScriptNumberFormatter.format(value.to_f)
        when Float
          EcmaScriptNumberFormatter.format(value)
        when true
          "true"
        when false
          "false"
        when Array
          "[#{value.map { |item| JSON.generate(item) }.join(',')}]"
        else
          raise TypeError, "Unsupported JSON wire value #{value.class}."
        end
      end
      private_class_method :encode_wire_value
    end
  end
end
