defmodule LuaNoxWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use LuaNoxWeb, :html

  import LuaNoxWeb.NavBar

  embed_templates("layouts/*")

  def app(%{current_scope: _} = assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <header>
        <.navbar current_scope={@current_scope} />
      </header>

      <main
        class="grow transition-all duration-500 ease-in-out opacity-0 phx-page-loading:opacity-0"
        phx-mounted={JS.remove_class("opacity-0")}
      >
        <div class="mx-auto">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer>
        <.footer />
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <%!-- <span class="inline-flex items-baseline"> --%>
        <%!--   <.icon name={:refresh} type={:outline} class="ml-1 size-3 motion-safe:animate-spin" /> --%>
        <%!-- </span> --%>
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <%!-- <span class="inline-flex items-baseline"> --%>
        <%!--   <.icon name={:refresh} type={:outline} class="ml-1 size-3 motion-safe:animate-spin" /> --%>
        <%!-- </span> --%>
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="dropdown dropdown-end md:dropdown-center">
      <div tabindex="0" role="button" class="btn btn-ghost btn-square" aria-label="Theme">
        <span class="relative inline-flex size-5">
          <.icon
            name={:device_desktop_cog}
            type={:outline}
            class="size-5 [[data-theme]_&]:hidden"
          />
          <.icon
            name={:sun}
            type={:outline}
            class="size-5 hidden [[data-theme=light]_&]:inline"
          />
          <.icon
            name={:moon_stars}
            type={:outline}
            class="size-5 hidden [[data-theme=dark]_&]:inline"
          />
        </span>
      </div>
      <ul tabindex="0" class="dropdown-content menu bg-base-200 border border-base-300 rounded-box z-50 shadow-2xl mt-2 p-2 w-48 text-sm">
        <li>
          <button
            phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
            aria-label="System"
          >
            <span class="relative inline-flex size-5">
              <.icon name={:device_desktop_cog} type={:outline} class="size-4" />
            </span>
            System
            <.icon name={:check} type={:outline} class="ml-auto size-4 [[data-theme]_&]:hidden" />
          </button>
        </li>
        <li>
          <button
            phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
            aria-label="Light"
          >
            <.icon name={:sun} type={:outline} class="size-4" />
            Light
            <.icon name={:check} type={:outline} class="ml-auto size-4 hidden [[data-theme=light]_&]:inline" />
          </button>
        </li>
        <li>
          <button
            phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
            aria-label="Dark"
          >
            <.icon name={:moon_stars} type={:outline} class="size-4" />
            Dark
            <.icon name={:check} type={:outline} class="ml-auto size-4 hidden [[data-theme=dark]_&]:inline" />
          </button>
        </li>
      </ul>
    </div>
    """
  end
end
