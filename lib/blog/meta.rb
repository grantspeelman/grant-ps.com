require "nokogiri"
require "uri"
require "time"

module Blog
  # Builds site/feed.xml (RSS 2.0, shaped for dev.to's RSS import) and site/sitemap.xml
  # from the markdown alone. Output depends only on the inputs, so it is byte-stable.
  class Meta
    MIME = { ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
             ".gif" => "image/gif", ".webp" => "image/webp", ".svg" => "image/svg+xml",
             ".avif" => "image/avif" }.freeze

    def initialize(site) = @site = site

    def files
      posts = @site.posts
      { "feed.xml" => feed(posts), "sitemap.xml" => sitemap(posts) }
    end

    def feed(posts = @site.posts)
      c = @site.config
      x = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
      x << %(<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/">\n)
      x << "  <channel>\n"
      x << "    <title>#{esc(c.fetch('title'))}</title>\n"
      x << "    <link>#{esc(@site.home_url)}</link>\n"
      x << "    <description>#{esc(c['description'] || "Writing by #{c.fetch('author')}")}</description>\n"
      x << "    <language>#{esc(c['language'] || 'en')}</language>\n"
      x << %(    <atom:link href="#{esc(@site.feed_url)}" rel="self" type="application/rss+xml"/>\n)
      x << "    <lastBuildDate>#{rfc822(posts.map(&:lastmod).max)}</lastBuildDate>\n" if posts.any?
      posts.each { |p| x << item(p) }
      x << "  </channel>\n</rss>\n"
    end

    def sitemap(posts = @site.posts)
      x = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
      x << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
      x << url_entry(@site.home_url, posts.map(&:lastmod).max)
      posts.each { |p| x << url_entry(@site.post_url(p.slug), p.lastmod) }
      x << "</urlset>\n"
    end

    # Rendered from the markdown (never from Claude's page), with every URL made absolute.
    def content_html(post)
      base = @site.post_url(post.slug)
      frag = Nokogiri::HTML5.fragment(Markdown.render(post.body))
      frag.css("[src]").each { |n| n["src"] = absolute(base, n["src"]) }
      frag.css("[href]").each { |n| n["href"] = absolute(base, n["href"]) }
      frag.css("[srcset]").each do |n|
        n["srcset"] = n["srcset"].split(",").map do |cand|
          url, *desc = cand.strip.split(/\s+/)
          [absolute(base, url), *desc].join(" ")
        end.join(", ")
      end
      frag.to_html.strip
    end

    private

    def item(post)
      url = @site.post_url(post.slug)
      x = +"    <item>\n"
      x << "      <title>#{esc(post.title)}</title>\n"
      x << "      <link>#{esc(url)}</link>\n"
      x << %(      <guid isPermaLink="true">#{esc(url)}</guid>\n)
      x << "      <pubDate>#{rfc822(post.date)}</pubDate>\n"
      x << "      <description>#{esc(post.description)}</description>\n"
      post.tags.first(Post::MAX_TAGS).each { |t| x << "      <category>#{esc(t)}</category>\n" }
      if post.og_image
        path = File.join(post.dir, post.og_image)
        type = MIME.fetch(File.extname(path).downcase, "application/octet-stream")
        x << %(      <enclosure url="#{esc(absolute(url, post.og_image))}" length="#{File.size(path)}" type="#{type}"/>\n)
      end
      x << "      <content:encoded>#{cdata(content_html(post))}</content:encoded>\n"
      x << "    </item>\n"
    end

    def url_entry(loc, lastmod)
      x = +"  <url>\n    <loc>#{esc(loc)}</loc>\n"
      x << "    <lastmod>#{lastmod.iso8601}</lastmod>\n" if lastmod
      x << "  </url>\n"
    end

    def rfc822(date) = date.strftime("%a, %d %b %Y 00:00:00 +0000")

    def absolute(base, url)
      return url if url.nil? || url.strip.empty?
      URI.join(base, url.strip).to_s
    rescue URI::Error => e
      raise ArgumentError, "cannot make #{url.inspect} absolute against #{base}: #{e.message}"
    end

    def esc(s) = s.to_s.encode(xml: :text).gsub('"', "&quot;")

    def cdata(s) = "<![CDATA[#{s.gsub(']]>', ']]]]><![CDATA[>')}]]>"
  end
end
