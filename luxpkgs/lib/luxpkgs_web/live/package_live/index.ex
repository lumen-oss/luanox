defmodule LuxpkgsWeb.PackageLive.Index do
  alias Luxpkgs.Packages
  use LuxpkgsWeb, :live_view

  import LuxpkgsWeb.PackageBox

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    # Convert simple params to Flop format
    flop_params = convert_to_flop_params(params)

    case Packages.list_packages_paginated(flop_params) do
      {:ok, {packages, meta}} ->
        {:noreply,
         socket
         |> assign(:packages, packages)
         |> assign(:meta, meta)
         |> assign(:params, params)}

      {:error, meta} ->
        {:noreply,
         socket
         |> assign(:packages, [])
         |> assign(:meta, meta)
         |> assign(:params, params)}
    end
  end

  def handle_event("update_filter", params, socket) do
    # Clean up empty values
    clean_params =
      params
      |> Enum.reject(fn {_key, value} -> value == "" end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/packages?#{clean_params}")}
  end

  # Convert simple URL params to Flop format
  defp convert_to_flop_params(params) do
    flop_params = %{}

    # Handle search
    flop_params =
      case params["search"] do
        search when is_binary(search) and search != "" ->
          Map.put(flop_params, :filters, [
            %{field: :search, op: :ilike, value: search}
          ])

        _ ->
          flop_params
      end

    # Handle sorting
    flop_params =
      case params["sort"] do
        "name" ->
          flop_params
          |> Map.put(:order_by, [:name])
          |> Map.put(:order_directions, [:asc])

        _ ->
          flop_params
          |> Map.put(:order_by, [:inserted_at])
          |> Map.put(:order_directions, [:desc])
      end

    # Handle pagination
    flop_params =
      if page = params["page"] do
        Map.put(flop_params, :page, String.to_integer(page))
      else
        flop_params
      end

    flop_params
  end
end
