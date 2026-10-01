require "nokogiri"
require "uri"

module Blog
  # Proves a post's index.html contains the author's words from index.md exactly.
  class Guard
    Result = Struct.new(:slug, :errors) do
      def ok? = errors.empty?
    end

    INTRO = "home intro"

    # What the mismatch message names: the guarded text, its markdown source and its container.
    Text = Struct.new(:what, :source, :marker)
    POST_TEXT = Text.new("post body text", "index.md", "[data-post-body]")
    INTRO_TEXT = Text.new("home page intro", "site/intro.md", "[data-intro]")

    def initialize(site) = @site = site

    def check(slug)
      dir = File.join(@site.posts_dir, slug)
      return Result.new(slug, ["no post folder site/posts/#{slug}/index.md"]) unless File.file?(File.join(dir, "index.md"))

      begin
        post = Post.load(dir)
      rescue FrontmatterError => e
        return Result.new(slug, ["index.md: #{e.message}"])
      end
      errors = post.errors.map { |e| "frontmatter: #{e}" }
      return Result.new(slug, errors + ["missing site/posts/#{slug}/index.html (run /publish #{slug})"]) unless File.file?(post.html_path)

      doc = Nokogiri::HTML5(File.read(post.html_path))
      errors.concat(check_page(post, doc))

      bodies = doc.css("[data-post-body]")
      if bodies.size != 1
        errors << "page must have exactly one [data-post-body] element, found #{bodies.size}"
        return Result.new(slug, errors)
      end
      body = bodies.first.dup
      body.css("[data-flare]").each(&:remove)
      expected_frag = Nokogiri::HTML5.fragment(Markdown.render(post.body))

      errors.concat(compare_blocks(Blocks.extract(expected_frag), Blocks.extract(body), POST_TEXT))
      errors.concat(check_targets(@site.post_url(post.folder), expected_frag, body, "post body"))
      Result.new(slug, errors)
    end

    # Proves the home page's [data-intro] contains Grant's intro from site/intro.md exactly.
    # Until site/intro.md exists there is nothing to guard: the page shows a TODO placeholder.
    def check_intro
      return Result.new(INTRO, []) unless File.file?(@site.intro_path)
      home = File.join(@site.site_dir, "index.html")
      return Result.new(INTRO, ["missing site/index.html"]) unless File.file?(home)

      intros = Nokogiri::HTML5(File.read(home)).css("[data-intro]")
      return Result.new(INTRO, ["site/index.html must have exactly one [data-intro] element, found #{intros.size} " \
                                "(put the output of bin/render --intro in it)"]) if intros.size != 1

      intro = intros.first.dup
      intro.css("[data-flare]").each(&:remove)
      expected_frag = Nokogiri::HTML5.fragment(Markdown.render(File.read(@site.intro_path)))
      errors = compare_blocks(Blocks.extract(expected_frag), Blocks.extract(intro), INTRO_TEXT)
      errors.concat(check_targets(@site.home_url, expected_frag, intro, "home page intro"))
      Result.new(INTRO, errors)
    end

    private

    def check_page(post, doc)
      errs = []
      h1s = doc.css("h1")
      if h1s.size != 1
        errs << "page must have exactly one <h1>, found #{h1s.size}"
      elsif post.title && Blocks.normalize(h1s.first.text) != Blocks.normalize(post.title.to_s)
        errs << "<h1> text does not equal frontmatter title\n    title: #{post.title}\n    <h1>:  #{Blocks.normalize(h1s.first.text)}"
      end
      canonical = @site.post_url(post.folder)
      found = doc.css('link[rel="canonical"]').map { |l| l["href"] }
      errs << "missing <link rel=\"canonical\" href=\"#{canonical}\"> (found: #{found.empty? ? 'none' : found.join(', ')})" unless found == [canonical]
      errs
    end

    def compare_blocks(expected, actual, t)
      exp = expected.map(&:comparable)
      act = actual.map(&:comparable)
      return [] if exp == act

      i = (0...[exp.size, act.size].max).find { |n| exp[n] != act[n] }
      msg = +"#{t.what} does not match #{t.source} (block #{i + 1} of #{expected.size} expected)\n"
      msg << "  markdown says: #{expected[i] ? expected[i].to_s : '(nothing: the page has extra content here)'}\n"
      msg << "  page has:      #{actual[i] ? actual[i].to_s : '(nothing: the page is missing content from here on)'}\n"
      if expected[i] && actual[i] && !expected[i].code? && !actual[i].code?
        msg << "  first difference at character #{first_diff(expected[i].text, actual[i].text)}: " \
               "#{snippet(expected[i].text, actual[i].text)}\n"
      elsif expected[i]&.code? && actual[i]&.code?
        ln = (0...[expected[i].lines.size, actual[i].lines.size].max).find { |n| expected[i].lines[n] != actual[i].lines[n] }
        msg << "  first differing code line #{ln + 1}: expected #{expected[i].lines[ln].inspect}, page has #{actual[i].lines[ln].inspect}\n"
      end
      msg << "  diff (- markdown, + page):\n"
      msg << short_diff(expected, actual, i)
      msg << "  Fix the HTML so its text matches the markdown exactly. Never edit #{t.source} to match the page.\n"
      msg << "  Content that is not the author's text must go outside #{t.marker} or inside a [data-flare] element."
      [msg]
    end

    def first_diff(a, b) = (0..[a.size, b.size].max).find { |n| a[n] != b[n] } + 1

    def snippet(a, b)
      n = first_diff(a, b) - 1
      from = [n - 20, 0].max
      "markdown #{a[from, 40].inspect} vs page #{b[from, 40].inspect}"
    end

    # A small LCS diff of the blocks around the first mismatch.
    def short_diff(expected, actual, i)
      from = [i - 2, 0].max
      e = expected[from, 8] || []
      a = actual[from, 8] || []
      ec = e.map(&:comparable)
      ac = a.map(&:comparable)
      lcs = Array.new(e.size + 1) { Array.new(a.size + 1, 0) }
      (e.size - 1).downto(0) do |x|
        (a.size - 1).downto(0) do |y|
          lcs[x][y] = ec[x] == ac[y] ? lcs[x + 1][y + 1] + 1 : [lcs[x + 1][y], lcs[x][y + 1]].max
        end
      end
      lines = []
      x = y = 0
      while x < e.size || y < a.size
        if x < e.size && y < a.size && ec[x] == ac[y]
          lines << "      #{e[x].to_s.lines.first.chomp}"
          x += 1
          y += 1
        elsif x < e.size && (y >= a.size || lcs[x + 1][y] >= lcs[x][y + 1])
          lines << "    - #{e[x].to_s.lines.first.chomp}"
          x += 1
        else
          lines << "    + #{a[y].to_s.lines.first.chomp}"
          y += 1
        end
      end
      lines.map { |l| l.length > 110 ? "#{l[0, 107]}...\n" : "#{l}\n" }.join
    end

    # Every image src and link href in the markdown must appear in the guarded element.
    def check_targets(base, expected_frag, body, where)
      want = targets(expected_frag, base)
      have = targets(body, base)
      (want - have).map do |kind, url|
        "#{kind} target from the markdown is missing from the #{where}: #{url}"
      end.uniq
    end

    def targets(node, base)
      node.css("img[src]").map { |n| [:image, resolve(base, n["src"])] } +
        node.css("a[href]").map { |n| [:link, resolve(base, n["href"])] }
    end

    def resolve(base, url)
      URI.join(base, url.strip).to_s
    rescue URI::Error
      url.strip
    end
  end
end
