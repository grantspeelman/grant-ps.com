require "test_helper"
require "json"
require "yaml"

# The repo's own config files must parse. The workflows under .github/workflows/ are
# checked by actionlint in CI.
class ConfigTest < Minitest::Test
  REPO = File.expand_path("..", __dir__)

  def test_site_yml_parses_the_way_the_tooling_loads_it
    config = YAML.safe_load_file(File.join(REPO, "site.yml"))
    assert_kind_of Hash, config
    %w[title base_url author repo_url source_url_template].each do |key|
      assert_kind_of String, config[key], "site.yml: `#{key}` should be a string"
    end
    assert_kind_of Array, config["writing_elsewhere"]
  end

  def test_wrangler_jsonc_parses
    config = JSON.parse(File.read(File.join(REPO, "wrangler.jsonc")), allow_comments: true, allow_trailing_comma: true)
    assert_kind_of Hash, config
    assert_equal "./site", config.dig("assets", "directory"), "wrangler.jsonc must serve the committed site/ folder"
  end
end
