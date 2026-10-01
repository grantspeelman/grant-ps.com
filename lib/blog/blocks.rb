require "nokogiri"

module Blog
  # Turns HTML into the sequence of text blocks the fidelity guard compares.
  #
  # A block is a heading, paragraph, list item, blockquote, table cell or code block.
  # Its text is its own text, excluding any nested blocks (which become blocks of their
  # own, in document order). Text outside any block also counts, as a "loose" block,
  # so words added between blocks are caught. Whitespace runs collapse to one space;
  # nothing else is normalised. Code blocks compare line by line.
  module Blocks
    Block = Struct.new(:kind, :tag, :text, :lines) do
      def code? = kind == :code

      def comparable = code? ? [:code, lines] : [:text, text]

      def to_s
        code? ? "<#{tag}> (code, #{lines.size} lines)\n" + lines.map { |l| "    | #{l}" }.join("\n") : "<#{tag}> #{text}"
      end
    end

    TEXT_BLOCKS = %w[h1 h2 h3 h4 h5 h6 p li blockquote td th dt dd figcaption].freeze
    SKIP = %w[script style template noscript].freeze
    WS = /[ \t\n\r\f]+/ # ASCII whitespace only: a non-breaking space is a real character.

    def self.normalize(text) = text.gsub(WS, " ").strip

    def self.extract(root)
      out = []
      loose = +""
      flush = lambda do
        t = normalize(loose)
        out << Block.new(:text, "loose text", t, nil) unless t.empty?
        loose.clear
      end
      visit = lambda do |node, in_block|
        node.children.each do |c|
          if c.text? || c.cdata?
            loose << c.text unless in_block
          elsif c.element?
            name = c.name.downcase
            next if SKIP.include?(name)
            if name == "br"
              loose << " " unless in_block
            elsif name == "pre"
              flush.call
              out << code_block(c)
            elsif TEXT_BLOCKS.include?(name)
              flush.call
              out << Block.new(:text, name, normalize(own_text(c)), nil)
              visit.call(c, true)
            else
              visit.call(c, in_block)
            end
          end
        end
      end
      visit.call(root, false)
      flush.call
      out.reject { |b| !b.code? && b.text.empty? }
    end

    def self.own_text(el)
      buf = +""
      el.children.each do |c|
        if c.text? || c.cdata?
          buf << c.text
        elsif c.element?
          name = c.name.downcase
          next if SKIP.include?(name) || name == "pre" || TEXT_BLOCKS.include?(name)
          name == "br" ? buf << " " : buf << own_text(c)
        end
      end
      buf
    end

    def self.code_block(pre)
      lines = pre.text.split("\n", -1).map(&:rstrip)
      lines.pop while lines.any? && lines.last.empty?
      lines.shift while lines.any? && lines.first.empty?
      Block.new(:code, "pre", nil, lines)
    end
  end
end
