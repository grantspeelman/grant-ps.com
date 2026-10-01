require "yaml"

module Blog
  # The repo as seen by the tooling. `root` is the repo root (or an exported copy of it).
  class Site
    attr_reader :root, :config

    def initialize(root = File.expand_path("../..", __dir__))
      @root = File.expand_path(root)
      @config = YAML.safe_load_file(File.join(@root, "site.yml"))
    end

    def site_dir = File.join(root, "site")
    def posts_dir = File.join(site_dir, "posts")
    def intro_path = File.join(site_dir, "intro.md")
    def base_url = config.fetch("base_url").chomp("/")
    def home_url = "#{base_url}/"
    def feed_url = "#{base_url}/feed.xml"
    def post_url(slug) = "#{base_url}/posts/#{slug}/"
    def source_url(slug) = format(config.fetch("source_url_template"), slug: slug)

    def post_slugs
      Dir.glob(File.join(posts_dir, "*", "index.md")).map { |f| File.basename(File.dirname(f)) }.sort
    end

    def post(slug) = Post.load(File.join(posts_dir, slug))

    # Every published post, newest first. Ties broken by slug so output is stable.
    def posts
      post_slugs.map { |s| post(s) }.sort_by { |p| [-p.date.jd, p.slug] }
    end
  end
end
