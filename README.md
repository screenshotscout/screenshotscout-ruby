# Screenshot Scout Ruby SDK

The official Ruby SDK for the [Screenshot Scout](https://screenshotscout.com) screenshot API.

> Status: initial local scaffold. The API client is not implemented or published yet.

The gem requires Ruby 3.4 or newer and will use the RubyGems name `screenshotscout`.
Its blocking client will use a small `Net::HTTP` adapter by default and will accept an
injectable transport for application-controlled transport configuration.

## Repository layout

- `lib` contains the `ScreenshotScout` namespace.
- `sig` contains the public RBS declarations.
- `test` contains focused SDK tests.
- `examples` will contain runnable usage examples when the client is implemented.

## Development

Install the development dependencies and run the local checks with Ruby 3.4 or newer:

```shell
bundle install
bundle exec rubocop
bundle exec rake test
bundle exec rbs -I sig validate
```

## License

Licensed under the [MIT License](LICENSE).
