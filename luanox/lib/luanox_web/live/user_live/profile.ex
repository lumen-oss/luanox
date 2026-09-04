defmodule LuaNoxWeb.UserLive.Profile do
  alias LuaNox.Accounts
  alias LuaNox.Packages
  use LuaNoxWeb, :live_view

  import LuaNoxWeb.PackageBox

  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> redirect(to: ~p"/")}

      user ->
        packages = Packages.list_packages_by_user(user)

        total_downloads =
          Enum.reduce(packages, 0, fn package, acc ->
            acc + Enum.sum(for(release <- package.releases, do: release.download_count))
          end)

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:packages, packages)
         |> assign(:total_downloads, total_downloads)
         |> assign(:page_title, user.aka || user.username)}
    end
  end

  defp member_since_date(%DateTime{} = date), do: Calendar.strftime(date, "%B %Y")
  defp member_since_date(%NaiveDateTime{} = date), do: Calendar.strftime(date, "%B %Y")
  defp member_since_date(_), do: "Unknown"
end
