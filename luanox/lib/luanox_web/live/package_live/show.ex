defmodule LuaNoxWeb.PackageLive.Show do
  alias LuaNox.Packages
  use LuaNoxWeb, :live_view

  def mount(%{"name" => name}, _session, socket) do
    case Packages.get_package(name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Package not found")
         |> redirect(to: ~p"/packages")}

      package ->
        {:ok,
         socket
         |> assign(:package, package |> LuaNox.Repo.preload(:user))
         |> assign(:page_title, package.name)}
    end
  end

  def handle_params(%{"name" => name}, _url, socket) do
    {:noreply, assign(socket, :package_name, name)}
  end

  defp format_date(date) do
    case date do
      %DateTime{} -> Calendar.strftime(date, "%B %d, %Y")
      %NaiveDateTime{} -> Calendar.strftime(date, "%B %d, %Y")
      _ -> "Unknown"
    end
  end
end
