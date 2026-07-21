# frozen_string_literal: true

module ScreenshotScout
  module CaptureHttpMethod
    GET = "GET"
    POST = "POST"
  end

  module CaptureFormat
    GIF = "gif"
    JPEG = "jpeg"
    JPG = "jpg"
    PDF = "pdf"
    PNG = "png"
    TIFF = "tiff"
    WEBP = "webp"
  end

  module CaptureResponseType
    BINARY = "binary"
    JSON = "json"
  end

  module CaptureWaitUntil
    DOM_CONTENT_LOADED = "domcontentloaded"
    LOAD = "load"
    NETWORK_IDLE_0 = "networkidle0"
    NETWORK_IDLE_2 = "networkidle2"
  end

  module CaptureMediaType
    PRINT = "print"
    SCREEN = "screen"
  end

  module CaptureColorScheme
    AUTO = "auto"
    DARK = "dark"
    LIGHT = "light"
  end

  module CaptureImageMode
    FILL = "fill"
    FIT = "fit"
    STRETCH = "stretch"
  end

  module CaptureImageAnchor
    BOTTOM = "bottom"
    BOTTOM_LEFT = "bottom_left"
    BOTTOM_RIGHT = "bottom_right"
    CENTER = "center"
    LEFT = "left"
    RIGHT = "right"
    TOP = "top"
    TOP_LEFT = "top_left"
    TOP_RIGHT = "top_right"
  end

  module CapturePdfPaperFormat
    A3 = "a3"
    A4 = "a4"
    CONTENT = "content"
    LEGAL = "legal"
    LETTER = "letter"
    TABLOID = "tabloid"
  end

  module CaptureStorageMode
    EXTERNAL = "external"
    MANAGED = "managed"
  end
end
