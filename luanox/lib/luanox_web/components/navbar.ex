defmodule LuaNoxWeb.NavBar do
  use LuaNoxWeb, :html

  alias Phoenix.LiveView.JS

  alias LuaNox.Accounts.User

  def navbar(%{current_scope: _} = assigns) do
    ~H"""
    <nav class="navbar bg-base-300 shadow-sm px-4 md:text-lg">
      <div class="navbar-start flex-1">
        <.link class="flex items-center text-xl" navigate={~p"/"}>
          <.logo class="h-6 md:h-8 w-auto md:mr-2" />
          <span class="hidden md:inline font-semibold">Luanox</span>
        </.link>
      </div>
      
    <!-- Global menu items (always there no matters if mobile or desktop) -->
      <div class="flex items-center space-x-2 md:space-x-6">
        <LuaNoxWeb.Layouts.theme_toggle />
        <button
          class="md:hidden btn btn-ghost rounded-field text-grey hover:text-base-content"
          phx-click={
            JS.toggle(to: "#mobile-menu")
            |> JS.toggle_class("hidden", to: "#menu-icon")
            |> JS.toggle_class("hidden", to: "#close-icon")
          }
        >
          <.icon id="menu-icon" name={:menu_deep} type={:outline} class="size-5" />
          <.icon id="close-icon" name={:x} type={:outline} class="hidden hover:text-error size-5" />
        </button>
      </div>

      <.desktop_menu current_scope={@current_scope} />
      <.mobile_menu current_scope={@current_scope} />
    </nav>
    """
  end

  defp account_dropdown(%{current_scope: _} = assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <%= if @current_scope do %>
        <div tabindex="0" role="button" class="btn btn-ghost text-grey hover:text-info rounded-field">
          <.icon name={:user_circle} type={:outline} />
          <span class="mt-px">
            {User.unique_username(@current_scope.user) |> String.slice(0..20)}
          </span>
        </div>
      <% else %>
        <.link class="btn btn-ghost text-grey hover:text-info rounded-field" navigate={~p"/login"}>
          <.icon name={:user_circle} type={:outline} />
          <span class="mt-px">
            Log In
          </span>
        </.link>
      <% end %>
      <ul
        :if={@current_scope}
        tabindex="0"
        class="menu dropdown-content bg-base-100 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
      >
        <li>
          <.link href={~p"/settings"}>Settings</.link>
        </li>
        <li>
          <.link href={~p"/keys"}>API keys</.link>
        </li>
        <hr class="text-dark-grey mt-1 mb-1" />
        <li>
          <.link href={~p"/logout"} method="delete">Log out</.link>
        </li>
      </ul>
    </div>
    """
  end

  defp desktop_menu(assigns) do
    ~H"""
    <div class="hidden md:flex items-center space-x-2">
      <ul class="menu menu-horizontal px-1 space-x-2">
        <li>
          <.link
            class="btn btn-ghost text-grey hover:text-info"
            href="https://lumen-oss.github.io"
          >
            <.icon name={:book_2} type={:outline} />
            <span class="mt-px">Docs</span>
          </.link>
        </li>
        <li>
          <.link
            class="btn btn-ghost text-grey hover:text-info"
            navigate={~p"/donate"}
          >
            <.icon name={:heart} type={:outline} />
            <span class="mt-px">Donate</span>
          </.link>
        </li>
        <li>
          <.link
            class="btn btn-ghost text-grey hover:text-info"
            href="https://github.com/lumen-oss/luanox"
          >
            <.icon name={:brand_github} type={:outline} />
            <span class="mt-px">Source</span>
          </.link>
        </li>
        <.account_dropdown current_scope={@current_scope} />
      </ul>
    </div>
    """
  end

  defp mobile_menu(assigns) do
    ~H"""
    <div
      id="mobile-menu"
      class="hidden absolute top-16 left-0 w-full bg-base-300 rounded-b-md shadow-md flex-row items-center justify-between pt-2 pb-4 px-6 z-10"
    >
      <ul class="menu menu-horizontal justify-between w-full">
        <li>
          <.link
            class="btn btn-ghost text-grey hover:text-info"
            href="https://lumen-oss.github.io"
          >
            <.icon name={:book_2} type={:outline} />
            <span class="mt-px">Docs</span>
          </.link>
        </li>
        <li>
          <.link
            class="btn btn-ghost text-grey hover:text-info"
            navigate={~p"/donate"}
          >
            <.icon name={:heart} type={:outline} />
            <span class="mt-px">Donate</span>
          </.link>
        </li>
        <li>
          <.link
            class="btn btn-ghost text-grey hover:text-info"
            href="https://github.com/lumen-oss/luanox"
          >
            <.icon name={:brand_github} type={:outline} />
            <span class="mt-px">Source</span>
          </.link>
        </li>
        <hr class="border-l border-dark-grey h-auto" />
        <.account_dropdown current_scope={@current_scope} />
      </ul>
    </div>
    """
  end
end
