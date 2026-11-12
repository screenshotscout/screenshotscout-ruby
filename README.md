# Screenshot Scout Ruby SDK

The official Ruby SDK for the [Screenshot Scout](https://screenshotscout.com/) screenshot API.

Capture website screenshots from Ruby applications.

## Requirements

- Ruby 3.4 or newer

## Installation

Add the gem to your bundle:

```shell
bundle add screenshotscout
```

Or install it directly:

```shell
gem install screenshotscout
```

## Get your API credentials

[Sign up for Screenshot Scout](https://screenshotscout.com/auth/signup) or sign in, then open the
[API Keys page](https://screenshotscout.com/app/api-keys) and copy the access key. You only need the
secret key for [signed requests](#signed-requests).

Set the access key as the `SCREENSHOTSCOUT_ACCESS_KEY` environment variable, or
[pass it in code](#pass-the-keys-yourself).

## Capture a screenshot

Create a client and call `capture` with the page URL and any capture options. This example captures
the full page and saves the returned image:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
response = client.capture(
  "https://example.com",
  ScreenshotScout::CaptureOptions.new(full_page: true)
)

File.binwrite("screenshot.png", response.bytes)
puts response.screenshot_url
```

`capture` uses POST by default, or GET when the client has a secret key. It returns a
`BinaryCaptureResponse` when `response_type` is omitted or set to `CaptureResponseType::BINARY`.

## Request a JSON result

Set `response_type` to `CaptureResponseType::JSON` to receive capture metadata instead of binary
image or PDF output:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(
  response_type: ScreenshotScout::CaptureResponseType::JSON
)
response = client.capture("https://example.com", options)

puts response.result.screenshot_url
```

Unrecognized JSON result fields are retained in `response.result.additional_fields`.

## Use GET

POST is the default, or GET when the client has a secret key. Pass `CaptureHttpMethod::GET` when
you need a GET request:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(format: ScreenshotScout::CaptureFormat::WEBP)
response = client.capture(
  "https://example.com",
  options,
  method: ScreenshotScout::CaptureHttpMethod::GET
)

File.binwrite("screenshot.webp", response.bytes)
```

## Build a capture URL

Use `build_capture_url` when a browser, an HTML `<img>` element, or another application needs to
load the screenshot directly. It creates the URL without sending an API request:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(full_page: true, block_ads: true)
capture_url = client.build_capture_url("https://example.com", options)
puts capture_url
```

The generated URL contains the access key. When the client has a secret key, the URL is signed
automatically; otherwise it is unsigned. Treat it as sensitive. Before exposing generated URLs
to browsers or users, configure a secret key and enable **Require signed requests** for the API key
on the [API Keys page](https://screenshotscout.com/app/api-keys).

## Signed requests

Set the API key's secret key as the `SCREENSHOTSCOUT_SECRET_KEY` environment variable. The client
then signs its capture requests and the capture URLs it builds, with no change to your code:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY and SCREENSHOTSCOUT_SECRET_KEY

response = client.capture("https://example.com")
File.binwrite("signed-screenshot.png", response.bytes)
```

The secret key is used locally and is never transmitted. See the
[signed requests guide](https://screenshotscout.com/docs/signed-requests) for details.

## Pass the keys yourself

To use keys from somewhere other than the environment, such as a secrets manager or per-customer
settings, pass them to the client:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new(
  access_key: config.access_key,
  secret_key: config.secret_key # optional
)
```

If you pass either key, the client reads neither environment variable. If you pass no key, for
example because the variable holding it is `nil`, the client reads both environment variables
instead.

## Capture options

The target URL is the first argument to `capture`. Use snake_case keywords to customize the
capture:

- Output: `format`, `response_type`
- Network and location: `country`, `proxy`, `geolocation_latitude`, `geolocation_longitude`, `geolocation_accuracy`
- Cookies and webpage headers: `cookies`, `headers`
- Timing: `timeout`, `wait_until`, `navigation_timeout`, `delay`
- Device emulation: `device`, `device_viewport_width`, `device_viewport_height`, `device_scale_factor`, `device_is_mobile`, `device_has_touch`, `device_user_agent`
- Page behavior: `timezone`, `media_type`, `color_scheme`, `reduced_motion`
- Full page: `full_page`, `full_page_pre_scroll`, `full_page_pre_scroll_step`, `full_page_pre_scroll_step_delay`, `full_page_max_height`
- Blocking: `block_cookie_banners`, `block_ads`, `block_chat_widgets`
- DOM changes: `hide_selectors`, `click_selectors`, `click_all_selectors`, `inject_css`, `inject_js`, `bypass_csp`
- Framing: `selector`, `clip_x`, `clip_y`, `clip_width`, `clip_height`
- Image output: `image_width`, `image_height`, `image_mode`, `image_anchor`, `image_allow_upscale`, `image_background`, `image_quality`
- PDF: `pdf_paper_format`, `pdf_landscape`, `pdf_print_background`, `pdf_margin`, `pdf_margin_top`, `pdf_margin_right`, `pdf_margin_bottom`, `pdf_margin_left`, `pdf_scale`, `pdf_page_ranges`
- Caching: `cache`, `cache_ttl`, `cache_key`
- Storage: `storage_mode`, `storage_endpoint`, `storage_bucket`, `storage_region`, `storage_object_key`

Use the provided constants for documented values, or pass a string:

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(
  format: ScreenshotScout::CaptureFormat::WEBP,
  wait_until: ScreenshotScout::CaptureWaitUntil::LOAD
)
response = client.capture("https://example.com", options)
File.binwrite("screenshot.webp", response.bytes)
```

Options such as `cookies`, `headers`, selectors, CSS, and JavaScript accept arrays of strings.

See the [Screenshot Scout option reference](https://screenshotscout.com/docs/screenshot-options)
for service behavior and allowed values.

## HTTP timeouts and customization

The `timeout` capture option controls how long Screenshot Scout may spend capturing the page. It
does not configure your application's HTTP timeout.

Most applications can use the default `NetHttpTransport`. It waits up to 300 seconds for response
data, longer than the longest capture Screenshot Scout allows. To customize HTTP timeouts, proxies,
TLS, or logging, pass an object with a `call(request)` method. It receives a `TransportRequest` and
returns a `RawResponse`:

```ruby
require "net/http"
require "screenshotscout"
require "uri"

class ApplicationTransport
  def initialize(open_timeout:, read_timeout:)
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def call(request)
    uri = URI.parse(request.url)
    http_request = build_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    http.max_retries = 0
    response = http.start { |session| session.request(http_request) }

    ScreenshotScout::RawResponse.new(
      status: response.code.to_i,
      reason_phrase: response.message.to_s,
      headers: response.to_hash,
      content_type: response["content-type"],
      body: response.body.to_s.b
    )
  end

  private

  def build_request(uri, request)
    http_request = case request.method
                   when ScreenshotScout::CaptureHttpMethod::GET
                     Net::HTTP::Get.new(uri)
                   when ScreenshotScout::CaptureHttpMethod::POST
                     Net::HTTP::Post.new(uri)
                   else
                     raise ArgumentError, "Unsupported HTTP method #{request.method.inspect}."
                   end

    request.headers.each { |name, value| http_request[name] = value }
    http_request.body = request.body unless request.body.nil?
    http_request
  end
end

transport = ApplicationTransport.new(open_timeout: 10, read_timeout: 300)
client = ScreenshotScout::Client.new(transport: transport) # Reads SCREENSHOTSCOUT_ACCESS_KEY

response = client.capture("https://example.com")
File.binwrite("screenshot.png", response.bytes)
```

## Raw responses and errors

Every successful response exposes `raw_response`, containing the HTTP status, reason phrase,
headers, content type, and body. `APIError` provides the same response details.

```ruby
require "screenshotscout"

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY

begin
  client.capture("https://example.com")
  puts "Capture succeeded."
rescue ScreenshotScout::APIError => error
  warn [error.status, error.error_code, error.error_message].inspect
  warn error.errors.inspect
  warn error.response_body.inspect if error.response_body?
  warn error.raw_response.body.inspect
rescue ScreenshotScout::TransportError => error
  warn error.cause.inspect
rescue ScreenshotScout::ConfigurationError,
       ScreenshotScout::SerializationError,
       ScreenshotScout::ResponseDecodingError => error
  warn error.message
end
```

All SDK exceptions inherit from `ScreenshotScout::Error`, which you can rescue to handle any SDK
error.

## License

Licensed under the [MIT License](LICENSE).
