# frozen_string_literal: true

module ScreenshotScout
  module Internal
    # Formats IEEE-754 values like JavaScript String(number) and JSON.stringify.
    module EcmaScriptNumberFormatter
      module_function

      def format(value)
        raise ArgumentError, "Expected a finite floating-point value." unless value.finite?
        return "0" if value.zero?

        encoded = value.to_s.downcase
        return normalize_decimal(encoded) unless encoded.include?("e")

        match = /\A(-?)([0-9])(?:\.([0-9]+))?e([+-]?[0-9]+)\z/.match(encoded)
        raise ArgumentError, "Unexpected floating-point encoding." if match.nil?

        negative = match[1] == "-"
        digits = (match[2] + match[3].to_s).sub(/0+\z/, "")
        digits = "0" if digits.empty?
        exponent = Integer(match[4], 10)
        number = expand_digits(digits, exponent)
        negative ? "-#{number}" : number
      end

      def normalize_decimal(encoded)
        return encoded unless encoded.include?(".")

        encoded.sub(/0+\z/, "").sub(/\.\z/, "")
      end
      private_class_method :normalize_decimal

      def expand_digits(digits, exponent)
        decimal_position = exponent + 1
        if decimal_position.positive? && decimal_position <= 21
          if digits.length <= decimal_position
            digits + ("0" * (decimal_position - digits.length))
          else
            "#{digits[0, decimal_position]}.#{digits[decimal_position..]}"
          end
        elsif decimal_position > -6 && decimal_position <= 0
          "0.#{'0' * -decimal_position}#{digits}"
        else
          mantissa = digits.length == 1 ? digits : "#{digits[0]}.#{digits[1..]}"
          "#{mantissa}e#{'+' if exponent >= 0}#{exponent}"
        end
      end
      private_class_method :expand_digits
    end
  end
end
