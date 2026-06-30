defmodule LuaNox.Accounts.TotpSecret do
  use Ecto.Schema
  import Ecto.Changeset

  schema "totp_secrets" do
    field :secret, LuaNox.Encrypted.Binary
    field :last_used_step, :integer
    belongs_to :user, LuaNox.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(totp_secret, attrs) do
    totp_secret
    |> cast(attrs, [:secret, :user_id])
    |> validate_required([:secret, :user_id])
    |> unique_constraint(:user_id)
  end
end
