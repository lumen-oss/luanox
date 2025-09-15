defmodule LuaNox.Packages do
  @moduledoc """
  The Packages context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias LuaNox.Accounts.User
  alias LuaNox.Repo

  alias LuaNox.Packages.Package
  alias LuaNox.Accounts.Scope

  require Logger

  @doc """
  Subscribes to scoped notifications about any package changes.

  The broadcasted messages match the pattern:

    * {:created, %Package{}}
    * {:updated, %Package{}}

  """
  def subscribe_packages(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(LuaNox.PubSub, "user:#{key}:packages")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(LuaNox.PubSub, "user:#{key}:packages", message)
  end

  @doc """
  Returns a paginated list of packages using Flop.
  """
  def list_packages_paginated(flop_params \\ %{}) do
    Package
    |> preload(:releases)
    |> Flop.validate_and_run(flop_params, for: Package)
  end

  @doc """
  Returns the list of packages with a given search query.
  """
  def list_packages(:exact, query) when is_binary(query) do
    Package
    |> where([p], ilike(p.name, ^"%#{query}%"))
    |> preload(:releases)
    |> Repo.all()
  end

  def list_packages(:fuzzy, query) when is_binary(query) do
    raise "Not yet implemented"
  end

  @doc """
  Gets a single package.

  Raises `Ecto.NoResultsError` if the Package does not exist.
  """
  def get_package!(name) do
    Repo.get_by!(Package, name: name) |> Repo.preload(:releases)
  end

  def get_package(name) do
    case Repo.get_by(Package, name: name) do
      nil ->
        nil

      package ->
        package
        |> Repo.preload(:releases)
    end
  end

  @doc """
  Gets a single package.

  Raises `Ecto.NoResultsError` if the Package does not exist.
  """
  def get_package_by_id!(id) do
    Repo.get_by!(Package, id: id) |> Repo.preload(:releases)
  end

  def get_package_by_id(id) do
    case Repo.get_by(Package, id: id) do
      nil ->
        nil

      package ->
        package
        |> Repo.preload(:releases)
    end
  end

  @doc """
  Creates a package.
  """
  def create_package(
        %Scope{} = scope,
        %{"name" => _} = attrs
      ) do
    if has_permission?(scope, attrs) do
      with {:ok, package = %Package{}} <-
             %Package{}
             |> Package.changeset(attrs, scope)
             |> Repo.insert() do
        package = Repo.preload(package, :releases)
        broadcast(scope, {:created, package})
        {:ok, package}
      else
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, :insufficient_permissions}
    end
  end

  def create_package(_, _) do
    {:error, :insufficient_permissions}
  end

  @doc """
  Updates a package.

  ## Examples

      iex> update_package(package, %{field: new_value})
      {:ok, %Package{}}

      iex> update_package(package, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_package(
        %Scope{} = scope,
        %Package{} = package,
        %{summary: _, description: _} = attrs
      ) do
    if has_permission?(scope, package) do
      with {:ok, package = %Package{}} <-
             package
             |> Package.changeset(attrs, scope)
             |> Repo.update() do
        broadcast(scope, {:updated, package})
        {:ok, package}
      end
    else
      {:error, :insufficient_permissions}
    end
  end

  def update_package(_, _) do
    {:error, :insufficient_permissions}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking package changes.

  ## Examples

      iex> change_package(package)
      %Ecto.Changeset{data: %Package{}}

  """
  def change_package(
        %Scope{} = scope,
        %Package{} = package,
        attrs
      ) do
    if has_permission?(scope, package) do
      Package.changeset(package, attrs, scope)
    else
      Package.changeset(package, attrs, scope)
      |> Ecto.Changeset.add_error(:name, "insufficient permissions to change package")
    end
  end

  def change_package(_, _, _) do
    {:error, :insufficient_permissions}
  end

  alias LuaNox.Packages.Release

  @doc """
  Subscribes to scoped notifications about any release changes.

  The broadcasted messages match the pattern:

    * {:created, %Release{}}
    * {:updated, %Release{}}
    * {:deleted, %Release{}}

  """
  def subscribe_releases(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(LuaNox.PubSub, "user:#{key}:releases")
  end

  @doc """
  Returns the list of releases.

  ## Examples

      iex> list_releases(scope)
      [%Release{}, ...]

  """
  def list_releases(%Package{} = package) do
    Repo.get(Package, package)
    |> Repo.preload(:releases)
    |> Map.get(:releases)
  end

  @doc """
  Gets a single release.

  Raises `Ecto.NoResultsError` if the Release does not exist.

  ## Examples

      iex> get_release!(123)
      %Release{}

      iex> get_release!(456)
      ** (Ecto.NoResultsError)

  """
  def get_release!(id) do
    Repo.get_by!(Release, id: id)
  end

  def get_release(id) do
    Repo.get_by(Release, id: id)
  end

  def get_release_by_package_and_version(%Package{} = package, version) do
    Release
    |> where(package_id: ^package.id, version: ^version)
    |> Repo.one()
  end

  @doc """
  Creates a release.
  """
  def add_release(
        %Scope{} = scope,
        %Package{} = package,
        %{
          "package" => package_name,
          "version" => version,
          "rockspec" => %Plug.Upload{} = rockspec
        } = attrs
      ) do
    if has_permission?(scope, package) do
      case Multi.new()
           |> Multi.insert(
             :release,
             package
             |> Ecto.build_assoc(:releases)
             |> Release.changeset(%{attrs | "rockspec" => File.read!(rockspec.path)})
           )
           |> Multi.run(:copy_rockspec, fn _repo, %{release: release} ->
             case File.cp(
                    rockspec.path,
                    Application.get_env(:luanox, :rockspec_storage) <> "/" <>
                      "#{package_name}-#{version}.rockspec"
                  ) do
               :ok ->
                 {:ok, release}

               {:error, reason} ->
                 {:error, reason}
             end
           end)
           |> Repo.transaction() do
        {:ok, %{release: release}} ->
          broadcast(scope, {:created, release})
          {:ok, release}

        {:error, :copy_rockspec, reason, _changes} ->
          Logger.error("Failed to copy rockspec file: #{reason}")
          {:error, :file_copy_failed}

        {:error, _step, reason, _changes} ->
          Logger.error("Failed to create release: #{reason}")
          {:error, reason}
      end
    else
      {:error, :insufficient_permissions}
    end
  end

  def add_release(_, _, _) do
    {:error, :insufficient_permissions}
  end

  def increment_release_download_count(%Release{} = release) do
    release
    |> Ecto.Changeset.change(%{download_count: release.download_count + 1})
    |> Repo.update!()
  end

  # Regular scopes are not allowed to modify or create packages
  defp has_permission?(
         %Scope{user: %User{}, write_restricted: false, package_whitelist: _} =
           scope,
         %{"name" => _} = attrs
       ) do
    Scope.package_permitted?(scope, attrs)
  end

  defp has_permission?(
         %Scope{user: %User{} = user, write_restricted: false, package_whitelist: _} =
           scope,
         %Package{} = package
       ) do
    package.user_id == user.id && Scope.package_permitted?(scope, package)
  end

  defp has_permission?(%Scope{user: %User{}}, %{"name" => _}), do: false
  defp has_permission?(%Scope{user: %User{}}, %Package{}), do: false

  defp has_permission?(%Scope{user: %User{}} = scope, %Release{} = release) do
    release_scope = Scope.for_release(release)

    release_scope == scope && Scope.package_permitted?(scope, release.package)
  end
end
