defmodule LuaNox.Repo.Migrations.ChangeTotpSecretToBinary do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :totp_secret
      add :totp_secret, :binary
    end
  end
end
