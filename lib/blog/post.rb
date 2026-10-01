require "yaml"
require "date"

module Blog
  class FrontmatterError < StandardError; end

  # One post folder: index.md (frontmatter plus markdown), and usually index.html.
  class Post
    REQUIRED = %w[title slug date description].freeze
    ALLOWED = (REQUIRED + %w[updated tags og_image]).freeze
    SLUG_RE = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    TAG_RE = /\A[a-z0-9]+\z/
    MAX_TAGS = 4
    MAX_TAG_LENGTH = 20

    attr_reader :dir, :data, :body

    def self.load(dir) = new(dir, File.read(File.join(dir, "index.md")))

    def self.parse(text)
      match = text.match(/\A---\r?\n(.*?)\r?\n---\r?\n?(.*)\z/m)
      raise FrontmatterError, "index.md must start with a --- frontmatter block" unless match
      data = YAML.safe_load(match[1], permitted_classes: [Date]) || {}
      raise FrontmatterError, "frontmatter must be a YAML mapping" unless data.is_a?(Hash)
      [data, match[2]]
    rescue Psych::SyntaxError => e
      raise FrontmatterError, "frontmatter is not valid YAML: #{e.message}"
    end

    def initialize(dir, text)
      @dir = File.expand_path(dir)
      @data, @body = self.class.parse(text)
    end

    def folder = File.basename(dir)
    def slug = data["slug"]
    def title = data["title"]
    def description = data["description"]
    def tags = Array(data["tags"])
    def og_image = data["og_image"]
    def date = to_date(data["date"])
    def updated = data["updated"] && to_date(data["updated"])
    def lastmod = updated || date
    def html_path = File.join(dir, "index.html")

    # Returns a list of human-readable problems; empty means valid.
    def errors
      errs = []
      REQUIRED.each { |k| errs << "missing required field `#{k}`" if blank?(data[k]) }
      (data.keys - ALLOWED).each { |k| errs << "unknown field `#{k}` (allowed: #{ALLOWED.join(', ')})" }
      %w[title description].each { |k| errs << "`#{k}` must be a string" if data[k] && !data[k].is_a?(String) }

      if slug
        errs << "slug `#{slug}` must match #{SLUG_RE.source} (lowercase letters, digits, single hyphens)" unless slug.is_a?(String) && slug.match?(SLUG_RE)
        errs << "slug `#{slug}` does not equal folder name `#{folder}`" unless slug == folder
      end

      %w[date updated].each do |k|
        next if data[k].nil?
        begin
          to_date(data[k])
        rescue ArgumentError, TypeError
          errs << "`#{k}` must be an ISO 8601 date (YYYY-MM-DD), got #{data[k].inspect}"
        end
      end
      if data["date"].is_a?(Date) && data["updated"].is_a?(Date) && data["updated"] < data["date"]
        errs << "`updated` (#{data['updated']}) is before `date` (#{data['date']})"
      end

      if data.key?("tags")
        raw = data["tags"]
        if !raw.is_a?(Array)
          errs << "`tags` must be a list, e.g. [ai, ruby]"
        else
          errs << "at most #{MAX_TAGS} tags allowed (dev.to limit), got #{raw.size}" if raw.size > MAX_TAGS
          raw.each do |t|
            errs << "tag #{t.inspect} must be lowercase a-z0-9 only (dev.to rules)" unless t.is_a?(String) && t.match?(TAG_RE)
            errs << "tag #{t.inspect} is longer than #{MAX_TAG_LENGTH} characters" if t.is_a?(String) && t.length > MAX_TAG_LENGTH
          end
          errs << "tags must not repeat" if raw.uniq.size != raw.size
        end
      end

      if og_image
        if !og_image.is_a?(String) || og_image.start_with?("/") || og_image.match?(%r{\A[a-z]+:}i) || og_image.include?("..")
          errs << "`og_image` must be a file name relative to the post folder, got #{og_image.inspect}"
        elsif !File.file?(File.join(dir, og_image))
          errs << "`og_image` file #{og_image} does not exist in #{folder}/"
        end
      end
      errs
    end

    def valid? = errors.empty?

    private

    def blank?(v) = v.nil? || (v.respond_to?(:empty?) && v.empty?)

    def to_date(v)
      case v
      when Date then v
      when String then Date.iso8601(v)
      else raise TypeError, "not a date: #{v.inspect}"
      end
    end
  end
end
