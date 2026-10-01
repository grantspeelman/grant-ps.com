require "test_helper"

class PostTest < Minitest::Test
  include FixtureHelpers

  def post(fm, folder: "my-post")
    Dir.mktmpdir do |d|
      dir = File.join(d, folder)
      Dir.mkdir(dir)
      yaml = { "title" => "T", "slug" => folder, "date" => Date.new(2026, 10, 5), "description" => "D" }.merge(fm).compact.to_yaml
      File.write(File.join(dir, "index.md"), "#{yaml}---\nBody\n")
      return Blog::Post.load(dir).errors
    end
  end

  def test_valid_post
    assert_empty post({ "tags" => %w[ai ruby] })
  end

  def test_fixture_post_valid
    assert_empty Blog::Post.load(post_dir(FIXTURE_ROOT)).errors
  end

  def test_requires_fields
    errs = post({ "title" => nil, "description" => nil })
    assert_includes errs, "missing required field `title`"
    assert_includes errs, "missing required field `description`"
  end

  def test_rejects_bad_slugs
    ["Has-Caps", "under_score", "trailing-", "double--hyphen", "sp ace"].each do |bad|
      errs = post({ "slug" => bad })
      assert errs.any? { |e| e.include?("must match") }, "#{bad.inspect} should be rejected: #{errs}"
    end
  end

  def test_rejects_slug_not_matching_folder
    assert_includes post({ "slug" => "other-post" }), "slug `other-post` does not equal folder name `my-post`"
  end

  def test_rejects_bad_tags
    assert post({ "tags" => %w[a b c d e] }).any? { |e| e.include?("at most 4 tags") }
    assert post({ "tags" => ["Ruby"] }).any? { |e| e.include?("lowercase a-z0-9") }
    assert post({ "tags" => ["dev-ops"] }).any? { |e| e.include?("lowercase a-z0-9") }
    assert post({ "tags" => ["a" * 21] }).any? { |e| e.include?("longer than 20") }
    assert post({ "tags" => "ruby" }).any? { |e| e.include?("must be a list") }
  end

  def test_rejects_missing_og_image
    assert post({ "og_image" => "nope.png" }).any? { |e| e.include?("does not exist") }
    assert post({ "og_image" => "/abs.png" }).any? { |e| e.include?("relative to the post folder") }
  end

  def test_rejects_bad_dates_and_unknown_fields
    assert post({ "date" => "5 Oct" }).any? { |e| e.include?("ISO 8601") }
    assert post({ "updated" => Date.new(2026, 1, 1) }).any? { |e| e.include?("before `date`") }
    assert post({ "draft" => true }).any? { |e| e.include?("unknown field `draft`") }
  end

  def test_rejects_missing_frontmatter
    Dir.mktmpdir do |d|
      File.write(File.join(d, "index.md"), "No frontmatter")
      assert_raises(Blog::FrontmatterError) { Blog::Post.load(d) }
    end
  end
end
