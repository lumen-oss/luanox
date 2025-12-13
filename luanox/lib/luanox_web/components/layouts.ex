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
    <div class="hidden md:flex relative items-center bg-gradient-to-r from-base-200/80 to-base-300/80 backdrop-blur-sm border border-base-content/20">
      <div class="absolute w-[33.33%] h-full bg-gradient-to-r from-primary/20 to-primary/30 border border-primary/30 left-0 [[data-theme=light]_&]:left-[33.33%] [[data-theme=dark]_&]:left-[66.67%] transition-all duration-300 ease-out" />

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="relative z-10 px-3 py-2 transition-all duration-200 hover:bg-base-content/10 group"
      >
        <.icon
          name={:device_desktop_cog}
          type={:outline}
          class="size-4 opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-200"
        />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="relative z-10 px-3 py-2 transition-all duration-200 hover:bg-base-content/10 group"
      >
        <.icon
          name={:sun}
          type={:outline}
          class="size-4 opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-200"
        />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="relative z-10 px-3 py-2 transition-all duration-200 hover:bg-base-content/10 group"
      >
        <.icon
          name={:moon_stars}
          type={:outline}
          class="size-4 opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-200"
        />
      </button>
    </div>

    <div class="md:hidden dropdown dropdown-center">
      <div tabindex="0" role="button" class="btn btn-ghost">
        <.icon
          id="drop-system"
          name={:device_mobile_cog}
          type={:outline}
          class="size-5 [[data-theme=light]_&]:hidden [[data-theme=dark]_&]:hidden"
        />
        <.icon
          id="drop-light"
          name={:sun}
          type={:outline}
          class="hidden [[data-theme=light]_&]:inline size-5"
        />
        <.icon
          id="drop-dark"
          name={:moon_stars}
          type={:outline}
          class="hidden [[data-theme=dark]_&]:inline size-5"
        />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content bg-base-100 rounded-box z-1 w-30 p-2 text-md shadow-2xl"
      >
        <li>
          <input
            type="radio"
            name="theme-dropdown"
            class="theme-controller w-full btn btn-sm btn-block btn-ghost justify-start hover:bg-info"
            aria-label="System"
            value="system"
            phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
          />
        </li>
        <li>
          <input
            type="radio"
            name="theme-dropdown"
            class="theme-controller w-full btn btn-sm btn-block btn-ghost justify-start hover:bg-info"
            aria-label="Dark"
            value="dark"
            phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
          />
        </li>
        <li>
          <input
            type="radio"
            name="theme-dropdown"
            class="theme-controller w-full btn btn-sm btn-block btn-ghost justify-start hover:bg-info"
            aria-label="Light"
            value="light"
            phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
          />
        </li>
      </ul>
    </div>
    """
  end
end
