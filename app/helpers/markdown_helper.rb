module MarkdownHelper
  def markdown(text)
    return "" if text.blank?

    sanitize(renderer.render(text), scrubber: markdown_scrubber)
  end

  private

  def renderer
    @renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(
        hard_wrap: true,
        escape_html: true,
        safe_links_only: true,
        with_toc_data: true
      ),
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      no_intra_emphasis: true
    )
  end

  def markdown_scrubber
    @markdown_scrubber ||= begin
      scrubber = Rails::Html::PermitScrubber.new
      scrubber.tags = %w[
        p br strong em b i u strike s del
        h1 h2 h3 h4 h5 h6
        ul ol li
        pre code
        table thead tbody tr th td
        a img
        blockquote hr
        span div
      ]
      scrubber.attributes = %w[href target rel src alt class id]
      scrubber
    end
  end
end