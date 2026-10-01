require "test_helper"

class MetaTest < Minitest::Test
  include FixtureHelpers

  def meta(root = FIXTURE_ROOT) = Blog::Meta.new(Blog::Site.new(root))
  def feed_doc(root = FIXTURE_ROOT) = Nokogiri::XML(meta(root).feed) { |c| c.strict }

  def test_feed_is_valid_rss
    doc = feed_doc
    assert_equal "2.0", doc.root["version"]
    assert_equal "https://grant-ps.com/feed.xml", doc.at_xpath("//atom:link", "atom" => "http://www.w3.org/2005/Atom")["href"]
    assert_equal 1, doc.xpath("//item").size
  end

  def test_item_fields
    item = feed_doc.at_xpath("//item")
    url = "https://grant-ps.com/posts/good-post/"
    assert_equal url, item.at_xpath("link").text
    assert_equal url, item.at_xpath("guid").text
    assert_equal "true", item.at_xpath("guid")["isPermaLink"]
    assert_equal "Mon, 05 Oct 2026 00:00:00 +0000", item.at_xpath("pubDate").text
    assert_equal "A “good” fixture post", item.at_xpath("title").text
    assert_equal %w[testing ruby], item.xpath("category").map(&:text)
    enc = item.at_xpath("enclosure")
    assert_equal "https://grant-ps.com/posts/good-post/cover.png", enc["url"]
    assert_equal "image/png", enc["type"]
  end

  def test_content_urls_are_absolute
    html = feed_doc.at_xpath("//item/content:encoded", "content" => "http://purl.org/rss/1.0/modules/content/").text
    frag = Nokogiri::HTML5.fragment(html)
    urls = frag.css("[src]").map { |n| n["src"] } + frag.css("[href]").map { |n| n["href"] }
    refute_empty urls
    urls.each { |u| assert_match %r{\Ahttps://}, u }
    assert_includes urls, "https://grant-ps.com/posts/other-post/"
    assert_includes urls, "https://grant-ps.com/posts/good-post/cover.png"
    assert_includes html, "<p>This is the opening paragraph"
  end

  def test_max_four_categories
    with_fixture_copy do |root|
      path = File.join(post_dir(root), "index.md")
      File.write(path, File.read(path).sub("tags: [testing, ruby]", "tags: [a, b, c, d]"))
      assert_equal 4, feed_doc(root).xpath("//item/category").size
    end
  end

  def test_byte_stable
    assert_equal meta.files, meta.files
    with_fixture_copy do |root|
      assert_equal meta.files, meta(root).files, "output must not depend on paths or time"
    end
  end

  def test_cdata_terminator_is_escaped
    with_fixture_copy do |root|
      path = File.join(post_dir(root), "index.md")
      File.write(path, File.read(path) + "\nText with ]]> inside.\n")
      assert_includes feed_doc(root).at_xpath("//item/content:encoded", "content" => "http://purl.org/rss/1.0/modules/content/").text, "]]&gt;"
    end
  end

  def test_sitemap
    doc = Nokogiri::XML(meta.sitemap) { |c| c.strict }
    locs = doc.xpath("//xmlns:loc").map(&:text)
    assert_equal ["https://grant-ps.com/", "https://grant-ps.com/posts/good-post/"], locs
    assert_equal %w[2026-10-06 2026-10-06], doc.xpath("//xmlns:lastmod").map(&:text)
  end

  def test_newest_first
    with_fixture_copy do |root|
      older = post_dir(root, "older-post")
      FileUtils.mkdir_p(older)
      File.write(File.join(older, "index.md"), "---\ntitle: Old\nslug: older-post\ndate: 2025-01-01\ndescription: D\n---\nHi\n")
      assert_equal %w[A\ “good”\ fixture\ post Old], feed_doc(root).xpath("//item/title").map(&:text)
    end
  end
end
