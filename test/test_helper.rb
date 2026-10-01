require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "blog"

FIXTURE_ROOT = File.expand_path("fixtures/root", __dir__)

module FixtureHelpers
  # A throwaway copy of the fixture root, so tests can mutate it freely.
  def with_fixture_copy
    Dir.mktmpdir("blog-test") do |dir|
      FileUtils.cp_r("#{FIXTURE_ROOT}/.", dir)
      yield dir
    end
  end

  def post_dir(root, slug = "good-post") = File.join(root, "site/posts", slug)
end
