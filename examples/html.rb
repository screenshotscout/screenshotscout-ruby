# frozen_string_literal: true

require "screenshotscout"

html = <<~HTML
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <title>Invoice #1042</title>
      <style>
        body { font-family: system-ui, sans-serif; margin: 48px; color: #111; }
        table { width: 100%; border-collapse: collapse; margin-top: 24px; }
        th, td { text-align: left; padding: 8px 0; border-bottom: 1px solid #ddd; }
        .total td { font-weight: 600; }
      </style>
    </head>
    <body>
      <h1>Invoice #1042</h1>
      <p>Billed to Example Corp.</p>
      <table>
        <tr><th>Item</th><th>Amount</th></tr>
        <tr><td>Consulting, 4 hours</td><td>$480.00</td></tr>
        <tr class="total"><td>Total</td><td>$480.00</td></tr>
      </table>
    </body>
  </html>
HTML

client = ScreenshotScout::Client.new # Reads SCREENSHOTSCOUT_ACCESS_KEY
options = ScreenshotScout::CaptureOptions.new(format: ScreenshotScout::CaptureFormat::PDF)
response = client.capture_from_html(html, options)

File.binwrite("invoice.pdf", response.bytes)
puts response.screenshot_url
