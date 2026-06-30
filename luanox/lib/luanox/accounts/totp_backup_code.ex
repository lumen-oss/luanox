defmodule LuaNox.Accounts.TotpBackupCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "totp_backup_codes" do
    field :code_hash, :string
    belongs_to :user, LuaNox.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(totp_backup_code, attrs) do
    totp_backup_code
    |> cast(attrs, [:code_hash, :user_id])
    |> validate_required([:code_hash, :user_id])
  end
end
