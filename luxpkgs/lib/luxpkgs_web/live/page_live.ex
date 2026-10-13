defmodule LuxpkgsWeb.PageLive do
  alias Luxpkgs.Packages
  alias Luxpkgs.Accounts
  use LuxpkgsWeb, :live_view

  import LuxpkgsWeb.PackageBox

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:packages, Packages.list_packages(:exact, "", []) |> Map.get(:packages))
     |> assign(:featured, Packages.list_featured(4))
     |> assign(:active_users, Accounts.user_count())}
  end
end
