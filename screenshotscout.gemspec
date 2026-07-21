# frozen_string_literal: true

require_relative "lib/screenshotscout/version"

Gem::Specification.new do |spec|
  spec.name = "screenshotscout"
  spec.version = ScreenshotScout::VERSION
  spec.authors = ["Oleksii Velykyi"]

  spec.summary = "Official Ruby SDK for the Screenshot Scout screenshot API."
  spec.description = "A small, manually written Ruby client for Screenshot Scout."
  spec.homepage = "https://screenshotscout.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/screenshotscout/screenshotscout-ruby/issues",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/screenshotscout/screenshotscout-ruby"
  }

  spec.files = Dir[
    "LICENSE",
    "README.md",
    "examples/**/*",
    "lib/**/*.rb",
    "sig/**/*.rbs"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 6.0"
  spec.add_development_dependency "rake", "~> 13.4"
  spec.add_development_dependency "rbs", "~> 4.0"
  spec.add_development_dependency "rubocop", "~> 1.88"
end
