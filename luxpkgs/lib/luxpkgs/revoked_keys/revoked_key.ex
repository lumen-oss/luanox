defmodule Luxpkgs.RevokedKeys.RevokedKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "revoked_keys" do
    field :jti, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(key, %{revoked_key: revoked_key} = attrs) do
    case Luxpkgs.Guardian.decode_and_verify(revoked_key) do
      {:ok, claims} ->
        key
        |> cast(attrs, [:jti])
        |> put_change(:jti, claims["jti"])
        |> validate_required([:jti])
        |> unique_constraint(:jti, message: "key already revoked")

      _ ->
        key
        |> cast(attrs, [:jti])
        |> add_error(:revoked_key, "cannot revoke invalid key")
    end
  end
end
