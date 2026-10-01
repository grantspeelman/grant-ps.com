require "commonmarker"

module Blog
  # The one markdown renderer. The feed and the fidelity guard both use it, so they agree.
  module Markdown
    OPTIONS = {
      parse: { smart: false },
      render: { unsafe: true, hardbreaks: false, github_pre_lang: true },
      extension: {
        strikethrough: true, tagfilter: true, table: true, autolink: true,
        tasklist: true, footnotes: true, header_ids: nil
      }
    }.freeze

    def self.render(markdown)
      Commonmarker.to_html(markdown, options: OPTIONS, plugins: { syntax_highlighter: nil })
    end

    # The starting point for a page's [data-post-body]: the same render, with the one mechanical
    # change design/shell.md asks for. `<pre lang>` would tell screen readers the code is a human
    # language, so it becomes data-lang, and every <pre> gets tabindex="0" so it can be scrolled
    # from the keyboard. The words are untouched.
    def self.page_body(markdown)
      render(markdown).gsub(/<pre( lang="([^"]*)")?>/) do
        $2 ? %(<pre data-lang="#{$2}" tabindex="0">) : %(<pre tabindex="0">)
      end
    end
  end
end
