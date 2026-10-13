defmodule Luxpkgs.RevokedKeys do
  @moduledoc """
  The RevokedKeys context.
  """

  import Ecto.Query, warn: false
  alias Luxpkgs.Accounts.User
  alias Luxpkgs.Repo

  alias Luxpkgs.RevokedKeys.RevokedKey
  alias Luxpkgs.Accounts.Scope

  def is_revoked?(revoked_key) when is_binary(revoked_key) do
    with {:ok, claims} <- Luxpkgs.Guardian.decode_and_verify(revoked_key) do
      Repo.exists?(
        from r in RevokedKey,
          where: r.jti == ^claims["jti"]
      )
    end
  end

  def create_revoked_key(
        %Scope{user: %User{}, write_restricted: _, package_whitelist: _},
        %{revoked_key: revoked_key} = attrs
      )
      when is_binary(revoked_key) do
    case %RevokedKey{}
         |> RevokedKey.changeset(attrs)
         |> Repo.insert() do
      {:ok, _revoked_key} ->
        # don't return the revoked key
        {:ok}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_revoked_key(_, _attrs) do
    {:error, :insufficient_permissions}
  end
end
