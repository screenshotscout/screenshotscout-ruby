# frozen_string_literal: true

module ScreenshotScout
  # Keyword-initialized options for one Screenshot Scout capture.
  class CaptureOptions
    ATTRIBUTE_NAMES = %i[
      format response_type country proxy geolocation_latitude geolocation_longitude
      geolocation_accuracy cookies headers timeout wait_until navigation_timeout delay
      device device_viewport_width device_viewport_height device_scale_factor device_is_mobile
      device_has_touch device_user_agent timezone media_type color_scheme reduced_motion
      full_page full_page_pre_scroll full_page_pre_scroll_step full_page_pre_scroll_step_delay
      full_page_max_height block_cookie_banners block_ads block_chat_widgets hide_selectors
      click_selectors click_all_selectors inject_css inject_js bypass_csp selector clip_x clip_y
      clip_width clip_height image_width image_height image_mode image_anchor image_allow_upscale
      image_background image_quality pdf_paper_format pdf_landscape pdf_print_background
      pdf_margin pdf_margin_top pdf_margin_right pdf_margin_bottom pdf_margin_left pdf_scale cache
      cache_ttl cache_key storage_mode storage_endpoint storage_bucket storage_region
      storage_object_key
    ].freeze

    attr_reader(*ATTRIBUTE_NAMES)

    def initialize(**options)
      unknown = options.keys - ATTRIBUTE_NAMES
      unless unknown.empty?
        option = unknown.first
        raise SerializationError.new("Unknown capture option \"#{option}\".", option: option)
      end

      ATTRIBUTE_NAMES.each do |name|
        instance_variable_set("@#{name}", options[name])
      end
    end

    private_constant :ATTRIBUTE_NAMES
  end
end
