require "test_helper"
require "open3"

# Runs the real bin/guard and bin/meta executables against fixture copies.
class CommandsTest < Minitest::Test
  include FixtureHelpers

  BIN = File.expand_path("../bin", __dir__)

  def run_bin(name, root, *args)
    out, err, st = Open3.capture3(File.join(BIN, name), "--root", root, *args, chdir: root)
    [out + err, st.success?]
  end

  def guard(root, *args) = run_bin("guard", root, *args)

  def edit(root, rel)
    path = File.join(root, rel)
    File.write(path, yield(File.read(path)))
  end

  def break_intro(root) = edit(root, "site/index.html") { |h| h.sub("A second paragraph.", "A 2nd paragraph.") }
  def break_post(root) = edit(root, "site/posts/good-post/index.html") { |h| h.sub("<p>Last paragraph.</p>", "") }

  def assert_passes(result)
    out, ok = result
    assert ok, out
    out
  end

  def assert_fails(result, pattern)
    out, ok = result
    refute ok, "command should fail:\n#{out}"
    assert_match pattern, out
  end

  def test_guard_all_checks_posts_and_intro
    with_fixture_copy do |root|
      out = assert_passes guard(root, "--all")
      assert_match(/✓ good-post/, out)
      assert_match(/✓ home intro/, out)
    end
  end

  def test_guard_all_fails_when_intro_differs_from_intro_md
    with_fixture_copy do |root|
      edit(root, "site/intro.md") { |m| m.sub("A second paragraph.", "A changed paragraph.") }
      assert_fails guard(root, "--all"), /✗ home intro/
    end
  end

  def test_guard_all_fails_on_bad_post
    with_fixture_copy do |root|
      break_post(root)
      assert_fails guard(root, "--all"), /✗ good-post/
    end
  end

  def test_guard_all_fails_on_missing_page
    with_fixture_copy do |root|
      File.delete(File.join(post_dir(root), "index.html"))
      assert_fails guard(root, "--all"), %r{missing site/posts/good-post/index\.html}
    end
  end

  def test_guard_intro_checks_only_the_intro
    with_fixture_copy do |root|
      break_post(root)
      out = assert_passes guard(root, "--intro")
      refute_match(/good-post/, out)
      break_intro(root)
      assert_fails guard(root, "--intro"), /✗ home intro/
    end
  end

  def test_guard_slug_checks_only_that_post
    with_fixture_copy do |root|
      break_intro(root)
      out = assert_passes guard(root, "good-post")
      refute_match(/home intro/, out)
      break_post(root)
      assert_fails guard(root, "good-post"), /✗ good-post/
    end
  end

  def test_guard_unknown_slug_fails
    with_fixture_copy do |root|
      assert_fails guard(root, "no-such-post"), %r{no post folder site/posts/no-such-post}
    end
  end

  # With no arguments bin/guard checks only what is staged.
  def test_guard_without_arguments_checks_staged_changes
    with_fixture_copy do |root|
      git = ->(*a) { system("git", "-C", root, *a, out: File::NULL, err: File::NULL, exception: true) }
      git.("init", "-q", "-b", "main")
      git.("add", "-A")
      git.("-c", "user.email=t@example.com", "-c", "user.name=T", "commit", "-q", "--no-verify", "-m", "base")
      break_post(root)
      break_intro(root)
      assert_match(/nothing staged/, assert_passes(guard(root)))

      git.("add", "site/posts/good-post/index.html")
      result = guard(root)
      assert_fails result, /✗ good-post/
      refute_match(/home intro/, result.first)

      git.("reset", "-q")
      git.("add", "site/index.html")
      result = guard(root)
      assert_fails result, /✗ home intro/
      refute_match(/good-post/, result.first)
    end
  end

  def test_meta_check_fails_when_stale_and_passes_after_build
    with_fixture_copy do |root|
      assert_fails run_bin("meta", root, "--check"), %r{out of date: site/feed\.xml, site/sitemap\.xml}
      assert_passes run_bin("meta", root)
      assert_passes run_bin("meta", root, "--check")
      edit(root, "site/posts/good-post/index.md") { |m| m.sub("Last paragraph.", "Last paragraph, edited.") }
      assert_fails run_bin("meta", root, "--check"), %r{out of date: site/feed\.xml\.}
    end
  end

  def test_meta_refuses_invalid_frontmatter
    with_fixture_copy do |root|
      edit(root, "site/posts/good-post/index.md") { |m| m.sub("updated: 2026-10-06", "updated: 2026-10-04") }
      assert_fails run_bin("meta", root), /invalid frontmatter.*good-post: `updated`/m
      refute File.exist?(File.join(root, "site/feed.xml")), "nothing should be written"
    end
  end
end
