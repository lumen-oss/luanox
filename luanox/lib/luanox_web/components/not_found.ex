defmodule LuaNoxWeb.Components.NotFound do
  use LuaNoxWeb, :html

  attr(:title, :string, required: true)
  attr(:message, :string, required: true)

  def not_found(assigns) do
    ~H"""
    <div class="flex items-center justify-center max-w-6xl h-[calc(100vh-116px)] md:h-[calc(100vh-124px)] mx-auto px-6 md:px-4 lg:px-8 py-16 lg:py-24">
      <div class="bg-base-200 border border-base-300 rounded-box p-12 text-center max-w-xl mx-auto">
        <.icon
          name={:help_circle}
          type={:outline}
          class="w-14 h-14 lg:w-16 lg:h-16 text-primary mx-auto mb-4"
        />
        <h1 class="text-xl lg:text-2xl font-semibold text-base-content mb-2">
          {@title}
        </h1>
        <p class="text-base-content/70 mb-6">
          {@message}
        </p>
        <div class="flex flex-col sm:flex-row justify-center gap-2">
          <.link navigate={~p"/packages"} class="btn btn-primary">
            Browse packages
          </.link>
          <.link navigate={~p"/"} class="btn btn-neutral">
            Back to home
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
