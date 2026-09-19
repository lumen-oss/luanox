defmodule LuaNox.Accounts.UserRecoveryCode do
  use Ecto.Schema

  schema "user_recovery_codes" do
    field :code_hash, :string
    field :used_at, :utc_datetime
    belongs_to :user, LuaNox.Accounts.User

    timestamps(type: :utc_datetime)
  end
end