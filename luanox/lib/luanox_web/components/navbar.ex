defmodule LuaNoxWeb.NavBar do
  use LuaNoxWeb, :html

  alias Phoenix.LiveView.JS

  alias LuaNox.Accounts.User

  def navbar(%{current_scope: _} = assigns) do
    ~H"""
    <!-- Mobile menu backdrop overlay -->
    <div
      id="mobile-menu-backdrop"
      class="hidden fixed inset-0 bg-black/50 z-40 md:hidden opacity-0"
      phx-click={close_mobile_menu()}
    >
    </div>

    <nav class="navbar bg-base-300 shadow-sm px-4 md:text-lg relative z-50">
      <div class="navbar-start flex-1">
        <.link class="flex items-center text-xl" navigate={~p"/"}>
          <.logo class="h-6 md:h-8 w-auto mr-2" />
          <span class="font-semibold">Luanox</span>
        </.link>
      </div>

    <!-- Global menu items (always there no matters if mobile or desktop) -->
      <div class="flex items-center space-x-2 md:space-x-6">
        <LuaNoxWeb.Layouts.theme_toggle />
        <button
          class="md:hidden btn btn-ghost rounded-field text-grey hover:text-base-content p-2 min-h-[44px] min-w-[44px]"
          phx-click={toggle_mobile_menu()}
        >
          <.icon id="menu-icon" name={:menu_deep} type={:outline} class="size-6" />
          <.icon id="close-icon" name={:x} type={:outline} class="hidden hover:text-error size-6" />
        </button>
      </div>

      <.desktop_menu current_scope={@current_scope} />
      <.mobile_menu current_scope={@current_scope} />
    </nav>
    """
  end

  defp account_dropdown(%{current_scope: _} = assigns) do
    ~H"""
    <div class="dropdown dropdown-end max-sm:w-full">
      <%= if @current_scope do %>
        <div tabindex="0" role="button" class="btn btn-ghost btn-block justify-start text-grey hover:text-info rounded-field max-sm:px-1">
          <.icon name={:user_circle} type={:outline} />
          <span class="mt-px">
            {User.unique_username(@current_scope.user) |> String.slice(0..20)}
          </span>
        </div>
      <% else %>
        <.link class="btn btn-ghost btn-block justify-start text-grey hover:text-info rounded-field max-sm:px-1" navigate={~p"/login"}>
          <.icon name={:user_circle} type={:outline} />
          <span class="mt-px">
            Log In
          </span>
        </.link>
      <% end %>
      <ul
        :if={@current_scope}
        tabindex="0"
        class="menu dropdown-content bg-base-200 border border-base-300 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
      >
        <li>
          <.link navigate={~p"/settings"}>Settings</.link>
        </li>
        <li>
          <.link navigate={~p"/keys"}>API keys</.link>
        </li>
        <hr class="text-base-300 mt-1 mb-1" />
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
      class="hidden absolute top-full left-0 right-0 bg-base-300 rounded-b-lg shadow-xl border-t border-base-content/10 z-50 opacity-0 scale-95"
    >
      <div class="px-4 py-3">
        <ul class="menu menu-vertical w-full space-y-1">
          <li>
            <.link
              class="btn btn-ghost justify-start text-grey hover:text-info w-full min-h-[48px] px-4"
              href="https://lumen-oss.github.io"
              phx-click={close_mobile_menu()}
            >
              <.icon name={:book_2} type={:outline} class="size-5" />
              <span class="ml-3">Documentation</span>
            </.link>
          </li>
          <li>
            <.link
              class="btn btn-ghost justify-start text-grey hover:text-info w-full min-h-[48px] px-4"
              navigate={~p"/donate"}
              phx-click={close_mobile_menu()}
            >
              <.icon name={:heart} type={:outline} class="size-5" />
              <span class="ml-3">Donate</span>
            </.link>
          </li>
          <li>
            <.link
              class="btn btn-ghost justify-start text-grey hover:text-info w-full min-h-[48px] px-4"
              href="https://github.com/lumen-oss/luanox"
              phx-click={close_mobile_menu()}
            >
              <.icon name={:brand_github} type={:outline} class="size-5" />
              <span class="ml-3">Source Code</span>
            </.link>
          </li>
          <div class="divider my-2"></div>
          <li>
            <.account_dropdown current_scope={@current_scope} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp toggle_mobile_menu do
    # Scale + fade for the animations, overflow-hidden to prevent scrolling when open
    JS.toggle(
      to: "#mobile-menu",
      in: {"ease-out duration-200", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-in duration-150", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> JS.toggle(
      to: "#mobile-menu-backdrop",
      in: {"ease-out duration-200", "opacity-0", "opacity-100"},
      out: {"ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.toggle_class("hidden", to: "#menu-icon")
    |> JS.toggle_class("hidden", to: "#close-icon")
    |> JS.toggle_class("overflow-hidden", to: "body")
  end

  defp close_mobile_menu do
    JS.hide(
      to: "#mobile-menu",
      transition: {"ease-in duration-150", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> JS.hide(
      to: "#mobile-menu-backdrop",
      transition: {"ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.remove_class("hidden", to: "#menu-icon")
    |> JS.add_class("hidden", to: "#close-icon")
    |> JS.remove_class("overflow-hidden", to: "body")
  end
end
