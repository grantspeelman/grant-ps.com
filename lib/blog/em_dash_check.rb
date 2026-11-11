require "nokogiri"

module Blog
  # CLAUDE.md: no em-dashes in any copy Claude writes. Grant's own words may have them, and
  # those live only inside [data-post-body] and [data-intro], where bin/guard checks them
  # against the markdown. So an em-dash anywhere else in a page (head, title, meta, alt text,
  # chrome, the 404 page) is Claude's copy and fails. Flare ([data-flare]) is Claude's too,
  # so it is checked even inside the guarded elements.
  class EmDashCheck
    EM_DASH = "\u2014"
    GUARDED = "[data-post-body], [data-intro]"

    Hit = Struct.new(:path, :line, :where, :text) do
      def to_s = "#{path}:#{line}: em-dash in #{where}: #{text}"
    end

    # Every em-dash outside the author's guarded text in one page's HTML.
    def self.scan(html, path = "(html)")
      doc = Nokogiri::HTML5(html, max_tree_depth: -1)
      doc.css(GUARDED).each do |guarded|
        flare = guarded.css("[data-flare]").to_a
        guarded.children.each(&:unlink)
        flare.each { |f| guarded.add_child(f) }
      end

      hits = []
      doc.traverse do |node|
        if node.text? || node.comment?
          next unless node.content.include?(EM_DASH)
          where = node.comment? ? "a comment" : "text of <#{node.parent.name}>"
          hits << Hit.new(path, node.line, where, snippet(node.content))
        elsif node.element?
          node.attribute_nodes.each do |attr|
            next unless attr.value.include?(EM_DASH)
            hits << Hit.new(path, node.line, "#{attr.name}= of <#{node.name}>", snippet(attr.value))
          end
        end
      end
      hits
    end

    def self.scan_file(file, label = file) = scan(File.read(file), label)

    def self.snippet(s)
      i = s.index(EM_DASH)
      s[[i - 40, 0].max, 80].gsub(/\s+/, " ").strip
    end
  end
end
