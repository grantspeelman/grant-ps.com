require "test_helper"

class GuardTest < Minitest::Test
  include FixtureHelpers

  def check(root, slug = "good-post") = Blog::Guard.new(Blog::Site.new(root)).check(slug)

  # Apply a text substitution to the fixture page and return the guard result.
  def with_page_edit(from, to)
    with_fixture_copy do |root|
      path = File.join(post_dir(root), "index.html")
      html = File.read(path)
      assert html.include?(from), "fixture page should contain #{from.inspect}"
      File.write(path, html.sub(from, to))
      yield check(root)
    end
  end

  def assert_fails(result, pattern)
    refute result.ok?, "guard should fail"
    assert_match pattern, result.errors.join("\n")
  end

  def test_passes_known_good_page
    r = check(FIXTURE_ROOT)
    assert r.ok?, r.errors.join("\n")
  end

  def test_fails_on_dropped_paragraph
    with_page_edit("<p>Last paragraph.</p>", "") do |r|
      assert_fails r, /page is missing content from here on/
      assert_match "Last paragraph.", r.errors.join
    end
  end

  def test_fails_on_reworded_sentence
    with_page_edit("A quoted paragraph.", "A quoted passage.") { |r| assert_fails r, /quoted paragraph.*\n.*quoted passage/ }
  end

  def test_fails_on_changed_quote_character
    with_page_edit("“curly quotes”", "\"curly quotes\"") { |r| assert_fails r, /first difference at character/ }
  end

  def test_fails_on_dropped_code_line
    with_page_edit(%(  <span class="nb">puts</span> <span class="s">"hi"</span>\n), "") { |r| assert_fails r, /first differing code line 2/ }
  end

  def test_fails_on_reordered_list_items
    with_page_edit("<li><span>First item</span></li>", "") do |outer|
      refute outer.ok?
    end
    with_fixture_copy do |root|
      path = File.join(post_dir(root), "index.html")
      html = File.read(path)
      first = "<li><span>First item</span></li>"
      html = html.sub(first, "").sub("</ul>\n        </li>\n      </ul>", "</ul>\n        </li>\n        #{first}\n      </ul>")
      File.write(path, html)
      assert_fails check(root), /does not match/
    end
  end

  def test_fails_on_missing_link
    with_page_edit('<a href="https://example.com/a?b=c&amp;d=e">link</a>', "<span>link</span>") do |r|
      assert_fails r, %r{link target from the markdown is missing from the post body: https://example.com/a\?b=c&d=e}
    end
  end

  def test_fails_on_missing_image
    with_page_edit('<img src="cover.png" alt="A cover image">', "") { |r| assert_fails r, /image target.*cover\.png/ }
  end

  def test_relative_links_resolve_to_same_target
    with_page_edit('href="/posts/other-post/"', 'href="https://grant-ps.com/posts/other-post/"') { |r| assert r.ok?, r.errors.join("\n") }
  end

  def test_fails_on_added_text_outside_blocks
    with_page_edit("<figure>", "<figure>Photo by me") { |r| assert_fails r, /loose text.*Photo by me/ }
  end

  def test_ignores_flare_content
    with_page_edit("<p>Last paragraph.</p>", %(<p>Last paragraph.</p><div data-flare><p>Anything</p><pre>x</pre></div>)) do |r|
      assert r.ok?, r.errors.join("\n")
    end
  end

  def test_fails_on_wrong_title
    with_page_edit(%(<h1 class="title">A “good” fixture post</h1>), "<h1>A good fixture post</h1>") { |r| assert_fails r, /<h1> text does not equal/ }
  end

  def test_fails_on_missing_canonical
    with_page_edit(%(<link rel="canonical" href="https://grant-ps.com/posts/good-post/">), "") { |r| assert_fails r, /missing <link rel="canonical"/ }
  end

  def test_fails_without_post_body_marker
    with_page_edit(" data-post-body", "") { |r| assert_fails r, /exactly one \[data-post-body\]/ }
  end

  def test_fails_on_missing_html
    with_fixture_copy do |root|
      File.delete(File.join(post_dir(root), "index.html"))
      assert_fails check(root), /missing .*index\.html/
    end
  end

  def test_page_body_marks_code_blocks_for_the_shell
    html = Blog::Markdown.page_body("```ruby\nputs 1\n```\n\n    indented\n")
    assert_includes html, %(<pre data-lang="ruby" tabindex="0">)
    assert_includes html, %(<pre tabindex="0">)
    refute_match(/<pre lang=/, html)
  end

  def test_passes_page_built_from_bin_render_output
    with_fixture_copy do |root|
      path = File.join(post_dir(root), "index.html")
      doc = Nokogiri::HTML5(File.read(path))
      doc.at_css("[data-post-body]").inner_html = Blog::Markdown.page_body(Blog::Site.new(root).post("good-post").body)
      File.write(path, doc.to_html)
      r = check(root)
      assert r.ok?, r.errors.join("\n")
    end
  end
end
