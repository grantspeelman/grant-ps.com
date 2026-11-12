require "test_helper"
require "open3"

class EmDashCheckTest < Minitest::Test
  include FixtureHelpers

  DASH = "\u2014"

  def page(head: "", body: "")
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><title>Page</title>#{head}</head>
      <body>#{body}</body></html>
    HTML
  end

  def scan(html) = Blog::EmDashCheck.scan(html, "page.html")

  def test_fixture_pages_are_clean
    %w[site/index.html site/posts/good-post/index.html].each do |rel|
      assert_empty Blog::EmDashCheck.scan_file(File.join(FIXTURE_ROOT, rel))
    end
  end

  def test_flags_title
    hits = scan(page.sub("<title>Page</title>", "<title>Not found #{DASH} Grant</title>"))
    assert_equal 1, hits.size
    assert_equal "page.html:2: em-dash in text of <title>: Not found #{DASH} Grant", hits.first.to_s
  end

  def test_flags_html_entity
    assert_equal 1, scan(page(body: "<p>One &mdash; two</p>")).size
    assert_equal 1, scan(page(body: "<p>One &#8212; two</p>")).size
  end

  def test_flags_attributes_and_comments
    html = page(head: %(<meta name="description" content="a #{DASH} b">),
      body: %(<img src="x.png" alt="x #{DASH} y"><!-- note #{DASH} here -->))
    wheres = scan(html).map(&:where)
    assert_equal ["content= of <meta>", "alt= of <img>", "a comment"], wheres
  end

  def test_ignores_authors_guarded_text
    html = page(body: %(<div data-post-body><p>Grant #{DASH} wrote this</p></div>) +
      %(<div data-intro><p>Intro #{DASH} too</p></div>))
    assert_empty scan(html)
  end

  def test_flags_flare_inside_guarded_text
    html = page(body: %(<div data-post-body><p>Fine #{DASH} words</p><aside data-flare>Claude #{DASH} flare</aside></div>))
    hits = scan(html)
    assert_equal 1, hits.size
    assert_match "Claude #{DASH} flare", hits.first.text
  end

  def test_flags_chrome_next_to_guarded_text
    html = page(body: %(<header>Grant #{DASH} notes</header><div data-post-body><p>ok</p></div>))
    assert_equal 1, scan(html).size
  end

  def test_bin_script_exit_status
    with_fixture_copy do |root|
      out, st = Open3.capture2e(File.expand_path("../bin/em-dashes", __dir__), "--root", root)
      assert st.success?, out

      path = File.join(root, "site/index.html")
      File.write(path, File.read(path).sub("<title>Fixture home</title>", "<title>Home #{DASH} fixture</title>"))
      out, st = Open3.capture2e(File.expand_path("../bin/em-dashes", __dir__), "--root", root)
      refute st.success?
      assert_match %r{site/index\.html:5: em-dash in text of <title>}, out
    end
  end
end
