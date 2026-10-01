# Shared code for the blog's deterministic tooling (bin/meta, bin/guard, bin/precommit).
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require_relative "blog/site"
require_relative "blog/post"
require_relative "blog/markdown"
require_relative "blog/blocks"
require_relative "blog/guard"
require_relative "blog/meta"
require_relative "blog/precommit"
