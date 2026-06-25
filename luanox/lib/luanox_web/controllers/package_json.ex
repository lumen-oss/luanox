defmodule LuaNoxWeb.PackageJSON do
  alias LuaNoxWeb.ReleaseJSON
  alias LuaNox.Packages.Package

  def index(%{packages: packages, total_count: total, page: page, page_size: page_size, total_pages: total_pages}) do
    data =
      Enum.reduce(packages, %{}, fn package, acc ->
        data = data(package)

        Map.put(
          acc,
          data.name,
          data
          |> Map.drop([:name])
        )
      end)

    %{
      data: data,
      meta: %{
        total_count: total,
        page: page,
        page_size: page_size,
        total_pages: total_pages
      }
    }
  end

  def index(%{packages: packages}) do
    data =
      Enum.reduce(packages, %{}, fn package, acc ->
        data = data(package)

        Map.put(
          acc,
          data.name,
          data
          |> Map.drop([:name])
        )
      end)

    %{data: data}
  end

  @doc """
  Renders a single package.
  """
  def show(%{package: package}) do
    %{data: data(package)}
  end

  defp data(%Package{} = package) do
    %{
      name: package.name,
      summary: package.summary,
      description: package.description,
      releases: ReleaseJSON.index(%{releases: package.releases}).data
    }
  end
end
