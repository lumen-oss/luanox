defmodule LuaNoxWeb.UserLive.Profile do
  alias LuaNox.Accounts
  alias LuaNox.Packages
  use LuaNoxWeb, :live_view

  import LuaNoxWeb.Components.NotFound
  import LuaNoxWeb.PackageBox

  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> assign(:not_found, true)
         |> assign(:page_title, "User not found")}

      user ->
        {:ok,
         socket
         |> assign(:not_found, false)
         |> assign(:user, user)
         |> assign(:page_title, user.aka || user.username)}
    end
  end

  def handle_params(_params, _url, %{assigns: %{not_found: true}} = socket) do
    {:noreply, socket}
  end

  def handle_params(params, _url, socket) do
    user = socket.assigns.user
    flop_params = convert_to_flop_params(user.id, params)

    case Packages.list_packages_paginated(flop_params) do
      {:ok, {packages, meta}} ->
        {:noreply,
         socket
         |> assign(:packages, packages)
         |> assign(:meta, meta)
         |> assign(:params, params)
         |> assign(:total_downloads, Packages.total_downloads_by_user(user))}

      {:error, meta} ->
        {:noreply,
         socket
         |> assign(:packages, [])
         |> assign(:meta, meta)
         |> assign(:params, params)
         |> assign(:total_downloads, 0)}
    end
  end

  def handle_event("update_filter", params, socket) do
    clean_params =
      params
      |> Enum.reject(fn {_key, value} -> value == "" end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/users/#{socket.assigns.user.username}?#{clean_params}")}
  end

  defp convert_to_flop_params(user_id, params) do
    sort =
      case params["sort"] do
        "name" -> {"name", "asc"}
        _ -> {"inserted_at", "desc"}
      end

    %{
      filters: [%{field: :user_id, op: :==, value: user_id}],
      order_by: [String.to_atom(elem(sort, 0))],
      order_directions: [String.to_atom(elem(sort, 1))]
    }
    |> maybe_add_page(params)
  end

  defp maybe_add_page(flop_params, %{"page" => page}) when is_binary(page) do
    Map.put(flop_params, :page, String.to_integer(page))
  end

  defp maybe_add_page(flop_params, _params), do: flop_params

  defp member_since_date(%DateTime{} = date), do: Calendar.strftime(date, "%B %Y")
  defp member_since_date(%NaiveDateTime{} = date), do: Calendar.strftime(date, "%B %Y")
  defp member_since_date(_), do: "Unknown"
end
