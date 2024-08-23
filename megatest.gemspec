# frozen_string_literal: true

require_relative "lib/megatest/version"

Gem::Specification.new do |spec|
  spec.name = "megatest"
  spec.version = Megatest::VERSION
  spec.authors = ["Jean Boussier"]
  spec.email = ["jean.boussier@gmail.com"]

  spec.summary = "Modern test-unit style test framework"
  spec.description = "Largely API compatible with test-unit / minitest, but with lots of extra modern niceties like a proper CLI, test distribution, etc."
  spec.homepage = "https://github.com/byroot/megatest"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = File.join(spec.homepage, "blob/main/CHANGELOG.md")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[
          bin/
          test/
          spec/
          fixtures/
          features/
          .git
          .github
          .rubocop
          .rdoc_options
          appveyor
          Gemfile
          Rakefile
        ])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
