defmodule LuaNox.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `LuaNox.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias LuaNox.Packages.Release
  alias LuaNox.Repo
  alias LuaNox.Packages.Package
  alias LuaNox.Accounts.User

  defstruct user: nil, package_whitelist: nil, write_restricted: false

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user, package_whitelist: nil, write_restricted: false}
  end

  def for_user(nil), do: nil

  def for_package(%Package{} = package) do
    Repo.preload(package, :user) |> Map.get(:user) |> for_user()
  end

  def for_package(nil), do: nil

  def for_release(%Release{} = release) do
    Repo.preload(release, :package) |> Map.get(:package) |> for_package()
  end

  def for_release(nil), do: nil

  def for_jwt(%{
        user: %User{} = user,
        package_whitelist: package_whitelist,
        write_restricted: write_restricted
      }) do
    # NOTE(vhyrro): there appears to be an odd issue where
    # deserializing `null` from JSON gives `:null` (might be a recent addition? didn't happen earlier),
    # so we handle that case here
    package_whitelist =
      case package_whitelist do
        :null -> nil
        list when is_list(list) -> list
        _ -> nil
      end

    for_user(user)
    |> Map.put(:package_whitelist, package_whitelist)
    |> Map.put(:write_restricted, write_restricted)
  end

  def package_permitted?(%__MODULE__{package_whitelist: nil}, _package), do: true

  def package_permitted?(%__MODULE__{package_whitelist: package_whitelist}, %Package{} = package) do
    package.name in package_whitelist
  end

  def package_permitted?(%__MODULE__{package_whitelist: package_whitelist}, %{"name" => name}) do
    name in package_whitelist
  end
end
