require "test_helper"
require "json"
require "uri"

# Invariants of the real, committed config (not the fixtures). The workflows under
# .github/workflows/ are checked by actionlint in CI.
class ConfigTest < Minitest::Test
  REPO = File.expand_path("..", __dir__)

  def site = @site ||= Blog::Site.new(REPO)

  def test_site_yml_has_required_keys
    %w[title base_url author repo_url source_url_template default_og_image].each do |k|
      assert site.config[k].is_a?(String) && !site.config[k].strip.empty?, "site.yml needs a non-empty `#{k}`"
    end
    assert site.config.key?("analytics_token"), "site.yml needs an `analytics_token` key (empty is fine)"
    assert_kind_of Array, site.config["writing_elsewhere"]
    site.config["writing_elsewhere"].each do |w|
      %w[title url venue].each { |k| assert w[k].is_a?(String) && !w[k].empty?, "writing_elsewhere entry needs `#{k}`: #{w.inspect}" }
      assert_match %r{\Ahttps://}, w["url"]
    end
  end

  def test_base_url_is_https_without_trailing_slash
    base = site.config["base_url"]
    assert_match %r{\Ahttps://[^/]+\z}, base
    assert_equal "#{base}/posts/x/", site.post_url("x")
  end

  def test_default_og_image_exists
    path = site.config["default_og_image"]
    assert path.start_with?("/"), "default_og_image is a site-root path"
    assert File.file?(File.join(site.site_dir, path)), "site#{path} must exist"
  end

  def test_source_url_points_at_each_posts_markdown
    template = site.config["source_url_template"]
    assert_includes template, "%{slug}"
    prefix = "#{site.config["repo_url"].chomp("/")}/blob/main/"
    refute_empty site.post_slugs
    site.post_slugs.each do |slug|
      url = site.source_url(slug)
      assert url.start_with?(prefix), "#{url} must point into #{prefix}"
      rel = url.delete_prefix(prefix)
      assert_equal "site/posts/#{slug}/index.md", rel
      assert File.file?(File.join(REPO, rel)), "#{rel} must exist"
    end
  end

  # JSONC: drop // comments that are not inside strings, then parse as JSON.
  def wrangler
    text = File.read(File.join(REPO, "wrangler.jsonc"))
    JSON.parse(text.gsub(%r{("(?:\\.|[^"\\])*")|//[^\n]*}) { Regexp.last_match(1) || "" })
  end

  def test_wrangler_serves_the_site_folder
    assets = wrangler.fetch("assets")
    assert_equal "./site", assets["directory"]
    assert_equal "404-page", assets["not_found_handling"]
    assert_equal "auto-trailing-slash", assets["html_handling"]
    assert File.file?(File.join(REPO, "site/404.html")), "not_found_handling needs site/404.html"
  end

  def test_wrangler_is_assets_only_with_previews
    w = wrangler
    refute w.key?("main"), "the Worker is assets-only; a `main` script would change how site/ is served"
    assert w.key?("previews"), "`wrangler preview` needs the previews block"
    assert_match(/\A\d{4}-\d{2}-\d{2}\z/, w["compatibility_date"].to_s)
  end
end
