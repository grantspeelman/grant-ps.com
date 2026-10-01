require "test_helper"
require "open3"

# Runs the real bin/precommit against throwaway git repos built from the fixture root.
class PrecommitTest < Minitest::Test
  REPO = File.expand_path("..", __dir__)

  def setup
    @dir = Dir.mktmpdir("blog-precommit-test")
    FileUtils.cp_r("#{FIXTURE_ROOT}/.", @dir)
    %w[bin lib Gemfile Gemfile.lock].each { |f| FileUtils.cp_r(File.join(REPO, f), @dir) }
    File.write(File.join(@dir, ".gitignore"), "drafts/\n")
    git "init", "-q", "-b", "main"
    git "config", "user.email", "test@example.com"
    git "config", "user.name", "Test"
    system("#{@dir}/bin/meta", out: File::NULL, exception: true)
    git "add", "-A"
    assert precommit.last, "clean fixture should pass: #{precommit.first}"
    git "commit", "-q", "--no-verify", "-m", "base"
  end

  def teardown = FileUtils.rm_rf(@dir)

  def git(*args)
    out, st = Open3.capture2e("git", "-C", @dir, *args)
    raise out unless st.success?
    out
  end

  def precommit(env = {})
    out, st = Open3.capture2e(env, File.join(@dir, "bin/precommit"), chdir: @dir)
    [out, st.success?]
  end

  def edit(rel)
    path = File.join(@dir, rel)
    File.write(path, yield(File.read(path)))
  end

  def assert_blocked(pattern, env = {})
    out, ok = precommit(env)
    refute ok, "commit should be blocked"
    assert_match pattern, out
  end

  def test_allows_clean_change
    edit("site/posts/good-post/index.html") { |h| h.sub("<footer>", "<footer class=\"x\">") }
    git "add", "-A"
    out, ok = precommit
    assert ok, out
  end

  def test_blocks_guard_failure
    edit("site/posts/good-post/index.html") { |h| h.sub("<p>Last paragraph.</p>", "") }
    git "add", "-A"
    assert_blocked(/bin\/guard good-post failed/)
  end

  def test_checks_staged_version_not_working_tree
    edit("site/posts/good-post/index.html") { |h| h.sub("<p>Last paragraph.</p>", "") }
    git "add", "-A"
    edit("site/posts/good-post/index.html") { |h| h.sub("<footer>", "<p>Last paragraph.</p><footer>") }
    assert_blocked(/bin\/guard good-post failed/)
  end

  def test_blocks_stale_feed
    edit("site/posts/good-post/index.md") { |m| m.sub("Never published.", "Never ever published.") }
    git "add", "-A"
    assert_blocked(/site\/feed.xml out of date/)
  end

  def test_blocks_slug_mismatch
    edit("site/posts/good-post/index.md") { |m| m.sub("slug: good-post", "slug: other-slug") }
    git "add", "-A"
    assert_blocked(/frontmatter slug `other-slug` does not equal folder name `good-post`/)
  end

  def test_blocks_renamed_published_post
    git "mv", "site/posts/good-post", "site/posts/better-post"
    edit("site/posts/better-post/index.md") { |m| m.sub("slug: good-post", "slug: better-post") }
    system("#{@dir}/bin/meta", out: File::NULL)
    git "add", "-A"
    assert_blocked(/published post\(s\) deleted or renamed: good-post/)
  end

  def test_blocks_deleted_published_post_unless_escape_hatch
    git "rm", "-r", "-q", "site/posts/good-post"
    system("#{@dir}/bin/meta", out: File::NULL)
    git "add", "-A"
    assert_blocked(/deleted or renamed: good-post/)
    out, ok = precommit("ALLOW_SLUG_CHANGE" => "1")
    assert ok, out
    assert_match(/WARNING \(ALLOW_SLUG_CHANGE=1\)/, out)
  end

  def test_blocks_staged_drafts
    FileUtils.mkdir_p(File.join(@dir, "drafts/wip"))
    File.write(File.join(@dir, "drafts/wip/index.md"), "secret")
    git "add", "-f", "drafts/wip/index.md"
    assert_blocked(/files under drafts\/ are staged/)
  end
end
