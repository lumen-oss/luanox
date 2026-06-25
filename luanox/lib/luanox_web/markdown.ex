defmodule LuaNoxWeb.Markdown do
  use Phoenix.Component
  use PhoenixHtmlSanitizer, :basic_html
  import Phoenix.HTML, only: [raw: 1]

  def markdown(%{content: markdown} = assigns) when is_binary(markdown) do
    html = MDEx.to_html!(markdown,
            extension: [table: true, autolink: true, tagfilter: true],
            render: [unsafe: false]
          )

    assigns = assign(assigns, :html, html)

    ~H"""
    {raw(@html)}
    """
  end
end
