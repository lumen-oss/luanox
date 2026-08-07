defmodule LuaNoxWeb.PageLive do
  alias LuaNox.Packages
  alias LuaNox.Accounts
  use LuaNoxWeb, :live_view

  import LuaNoxWeb.PackageBox

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:packages, Packages.list_packages(:exact, "", []) |> Map.get(:packages))
     |> assign(:featured, Packages.list_featured(4))
     |> assign(:active_users, Accounts.user_count())}
  end
end
