require "open3"
require "tmpdir"

module Blog
  # The checks the pre-commit hook runs. Everything is evaluated against the staged
  # snapshot (the git index exported to a temp dir), not the working tree, so what is
  # checked is exactly what gets committed.
  class Precommit
    POST_PATH = %r{\Asite/posts/([^/]+)/}

    def initialize(repo, env: ENV, out: $stdout, err: $stderr)
      @repo = File.expand_path(repo)
      @env = env
      @out = out
      @err = err
    end

    # Posts with any staged change in their folder (including deletions).
    def self.staged_post_slugs(repo)
      new(repo).staged_paths.filter_map { |p| p[POST_PATH, 1] }.uniq.sort
    end

    def staged_paths = git("diff", "--cached", "--name-only", "-z", "--no-renames").split("\0")

    def run
      failures = []
      failures.concat(check_drafts)
      Dir.mktmpdir("blog-precommit") do |snap|
        git("checkout-index", "--all", "--prefix=#{snap}/")
        return fail_with(["site.yml is not staged or committed"]) unless File.file?(File.join(snap, "site.yml"))
        site = Site.new(snap)
        failures.concat(check_slugs(site))
        failures.concat(check_guard(site))
        failures.concat(check_meta(site))
      end
      failures.empty? ? (@out.puts("precommit: all checks passed") || true) : fail_with(failures)
    end

    private

    def fail_with(failures)
      @err.puts "precommit: commit blocked\n\n"
      failures.each { |f| @err.puts "✗ #{f.gsub("\n", "\n  ")}\n\n" }
      false
    end

    def check_drafts
      staged = git("diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR").split("\0").grep(%r{\Adrafts/})
      staged.empty? ? [] : ["files under drafts/ are staged; drafts are never committed:\n#{staged.join("\n")}\nUnstage with: git rm --cached -r drafts/"]
    end

    def check_slugs(site)
      failures = []
      staged_slugs = staged_paths.filter_map { |p| p[POST_PATH, 1] }.uniq
      staged_slugs.each do |slug|
        dir = File.join(site.posts_dir, slug)
        next unless File.file?(File.join(dir, "index.md"))
        begin
          post = Post.load(dir)
          failures << "site/posts/#{slug}: frontmatter slug `#{post.slug}` does not equal folder name `#{slug}`" if post.slug != slug
        rescue FrontmatterError => e
          failures << "site/posts/#{slug}/index.md: #{e.message}"
        end
      end

      published = head_post_slugs
      missing = published.reject { |s| File.file?(File.join(site.posts_dir, s, "index.md")) }
      if missing.any?
        msg = "published post(s) deleted or renamed: #{missing.join(', ')}\n" \
              "Published slugs are frozen. Changing one breaks its canonical URL, every link to it, " \
              "and the feed guid, so dev.to would import it as a new post."
        if @env["ALLOW_SLUG_CHANGE"] == "1"
          @err.puts "precommit: WARNING (ALLOW_SLUG_CHANGE=1): #{msg}\n\n"
        else
          failures << "#{msg}\nIf you really mean it, re-run with ALLOW_SLUG_CHANGE=1."
        end
      end
      failures
    end

    def check_guard(site)
      guard = Guard.new(site)
      staged_paths.filter_map { |p| p[POST_PATH, 1] }.uniq.sort.flat_map do |slug|
        next [] unless File.directory?(File.join(site.posts_dir, slug))
        r = guard.check(slug)
        r.ok? ? [] : ["bin/guard #{slug} failed:\n#{r.errors.join("\n")}"]
      end
    end

    def check_meta(site)
      stale = Meta.new(site).files.reject { |name, content| File.exist?(p = File.join(site.site_dir, name)) && File.read(p) == content }
      stale.empty? ? [] : ["#{stale.keys.map { |n| "site/#{n}" }.join(' and ')} out of date with the staged posts. Run bin/meta and stage the result."]
    end

    def head_post_slugs
      _, st = Open3.capture2e("git", "-C", @repo, "rev-parse", "--verify", "-q", "HEAD")
      return [] unless st.success?
      git("ls-tree", "--name-only", "HEAD", "site/posts/").split("\n")
        .map { |p| p.delete_prefix("site/posts/") }
        .select { |s| !git("ls-tree", "--name-only", "HEAD", "site/posts/#{s}/index.md").strip.empty? }
    end

    def git(*args)
      out, err, st = Open3.capture3("git", "-C", @repo, *args)
      raise "git #{args.join(' ')} failed: #{err}" unless st.success?
      out
    end
  end
end
