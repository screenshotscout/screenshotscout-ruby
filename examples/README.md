# Examples

- [`binary.rb`](binary.rb) captures a full-page screenshot, saves it as `screenshot.png`, and
  prints the returned screenshot URL.
- [`json.rb`](json.rb) requests a JSON response and prints the screenshot URL.
- [`capture_url.rb`](capture_url.rb) creates and prints a capture URL without sending an API
  request.

## Run the examples

From the repository root, install the dependencies:

```shell
bundle install
```

Set your access key. Set the optional secret key to use
[signed requests](../README.md#signed-requests) and signed capture URLs. The secret key is required
when **Require signed requests** is enabled for the API key.

PowerShell:

```powershell
$env:SCREENSHOTSCOUT_ACCESS_KEY = "YOUR_ACCESS_KEY"
$env:SCREENSHOTSCOUT_SECRET_KEY = "YOUR_SECRET_KEY"
```

macOS or Linux:

```shell
export SCREENSHOTSCOUT_ACCESS_KEY="YOUR_ACCESS_KEY"
export SCREENSHOTSCOUT_SECRET_KEY="YOUR_SECRET_KEY"
```

Run any example:

```shell
bundle exec ruby -Ilib examples/binary.rb
bundle exec ruby -Ilib examples/json.rb
bundle exec ruby -Ilib examples/capture_url.rb
```

Generated capture URLs contain the access key and should be treated as sensitive.
