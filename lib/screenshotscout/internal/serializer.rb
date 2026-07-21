# frozen_string_literal: true

module ScreenshotScout
  module Internal
    WirePair = Data.define(:name, :value)
    SerializedCaptureOptions = Data.define(:pairs, :body)

    # Converts CaptureOptions into the API's exact ordered wire representation.
    module Serializer
      WIRE_NAMES = {
        format: "format",
        response_type: "response_type",
        country: "country",
        proxy: "proxy",
        geolocation_latitude: "geolocation_latitude",
        geolocation_longitude: "geolocation_longitude",
        geolocation_accuracy: "geolocation_accuracy",
        cookies: "cookies",
        headers: "headers",
        timeout: "timeout",
        wait_until: "wait_until",
        navigation_timeout: "navigation_timeout",
        delay: "delay",
        device: "device",
        device_viewport_width: "device_viewport_width",
        device_viewport_height: "device_viewport_height",
        device_scale_factor: "device_scale_factor",
        device_is_mobile: "device_is_mobile",
        device_has_touch: "device_has_touch",
        device_user_agent: "device_user_agent",
        timezone: "timezone",
        media_type: "media_type",
        color_scheme: "color_scheme",
        reduced_motion: "reduced_motion",
        full_page: "full_page",
        full_page_pre_scroll: "full_page_pre_scroll",
        full_page_pre_scroll_step: "full_page_pre_scroll_step",
        full_page_pre_scroll_step_delay: "full_page_pre_scroll_step_delay",
        full_page_max_height: "full_page_max_height",
        block_cookie_banners: "block_cookie_banners",
        block_ads: "block_ads",
        block_chat_widgets: "block_chat_widgets",
        hide_selectors: "hide_selectors",
        click_selectors: "click_selectors",
        click_all_selectors: "click_all_selectors",
        inject_css: "inject_css",
        inject_js: "inject_js",
        bypass_csp: "bypass_csp",
        selector: "selector",
        clip_x: "clip_x",
        clip_y: "clip_y",
        clip_width: "clip_width",
        clip_height: "clip_height",
        image_width: "image_width",
        image_height: "image_height",
        image_mode: "image_mode",
        image_anchor: "image_anchor",
        image_allow_upscale: "image_allow_upscale",
        image_background: "image_background",
        image_quality: "image_quality",
        pdf_paper_format: "pdf_paper_format",
        pdf_landscape: "pdf_landscape",
        pdf_print_background: "pdf_print_background",
        pdf_margin: "pdf_margin",
        pdf_margin_top: "pdf_margin_top",
        pdf_margin_right: "pdf_margin_right",
        pdf_margin_bottom: "pdf_margin_bottom",
        pdf_margin_left: "pdf_margin_left",
        pdf_scale: "pdf_scale",
        cache: "cache",
        cache_ttl: "cache_ttl",
        cache_key: "cache_key",
        storage_mode: "storage_mode",
        storage_endpoint: "storage_endpoint",
        storage_bucket: "storage_bucket",
        storage_region: "storage_region",
        storage_object_key: "storage_object_key"
      }.freeze

      REPEATED_OPTIONS = %i[
        cookies headers hide_selectors click_selectors click_all_selectors inject_css inject_js
      ].freeze

      module_function

      def serialize(target_url, options)
        url = string_value(target_url, :url, target: true)
        unless options.nil? || options.is_a?(CaptureOptions)
          raise SerializationError, "Capture options must be a ScreenshotScout::CaptureOptions instance when provided."
        end

        pairs = [WirePair.new(name: "url", value: url)]
        body = { "url" => url }
        WIRE_NAMES.each do |property, wire_name|
          value = options&.public_send(property)
          next if value.nil?

          if REPEATED_OPTIONS.include?(property)
            append_repeated(pairs, body, property, wire_name, value)
          else
            append_scalar(pairs, body, property, wire_name, value)
          end
        end

        SerializedCaptureOptions.new(pairs: pairs.freeze, body: body.freeze)
      rescue Error
        raise
      rescue StandardError => e
        raise SerializationError.new("Capture options could not be serialized."), cause: e
      end

      def build_canonical_query(pairs, access_key)
        indexed = (pairs + [WirePair.new(name: "access_key", value: access_key)]).each_with_index.map do |pair, index|
          [pair, index]
        end
        indexed.sort! do |(left, left_index), (right, right_index)|
          comparison = left.name <=> right.name
          comparison.zero? ? left_index <=> right_index : comparison
        end
        encode_query(indexed.map(&:first))
      end

      def encode_query(pairs)
        pairs.map { |pair| "#{form_encode(pair.name)}=#{form_encode(pair.value)}" }.join("&")
      end

      def append_repeated(pairs, body, property, wire_name, value)
        unless value.is_a?(Array)
          raise SerializationError.new(
            "The capture option \"#{property}\" must be an array of strings.",
            option: property
          )
        end
        return if value.empty?

        copied = value.map do |item|
          string_value(item, property)
        end
        copied.each { |item| pairs << WirePair.new(name: wire_name, value: item) }
        body[wire_name] = copied.freeze
      end
      private_class_method :append_repeated

      def append_scalar(pairs, body, property, wire_name, value)
        pair_value, body_value = scalar_value(value, property)
        pairs << WirePair.new(name: wire_name, value: pair_value)
        body[wire_name] = body_value
      end
      private_class_method :append_scalar

      def scalar_value(value, property)
        case value
        when String
          string = string_value(value, property)
          [string, string]
        when Integer
          number = integer_value(value, property)
          [number, value]
        when Float
          unless value.finite?
            raise SerializationError.new(
              "The capture option \"#{property}\" must be a finite number.",
              option: property
            )
          end
          [EcmaScriptNumberFormatter.format(value), value]
        when true
          ["true", true]
        when false
          ["false", false]
        else
          raise SerializationError.new(
            "The capture option \"#{property}\" must be a string, finite number, or boolean.",
            option: property
          )
        end
      end
      private_class_method :scalar_value

      def integer_value(value, property)
        float_value = value.to_f
        return EcmaScriptNumberFormatter.format(float_value) if float_value.finite? && float_value.to_i == value

        raise SerializationError.new(
          "The capture option \"#{property}\" integer cannot be represented safely by the API.",
          option: property
        )
      end
      private_class_method :integer_value

      def string_value(value, property, target: false)
        unless value.is_a?(String)
          message = if target
                      "The capture target URL must be a string."
                    else
                      "The capture option \"#{property}\" must be a string."
                    end
          raise SerializationError.new(message, option: property)
        end

        value.encode(Encoding::UTF_8)
      rescue EncodingError => e
        message = if target
                    "The capture target URL must contain valid UTF-8."
                  else
                    "The capture option \"#{property}\" must contain valid UTF-8."
                  end
        raise SerializationError.new(message, option: property), cause: e
      end
      private_class_method :string_value

      def form_encode(value)
        value.bytes.map do |byte|
          if byte.between?(65, 90) || byte.between?(97, 122) ||
             byte.between?(48, 57) || [42, 45, 46, 95].include?(byte)
            byte.chr
          elsif byte == 32
            "+"
          else
            format("%%%02X", byte)
          end
        end.join
      end
      private_class_method :form_encode
    end
  end
end
