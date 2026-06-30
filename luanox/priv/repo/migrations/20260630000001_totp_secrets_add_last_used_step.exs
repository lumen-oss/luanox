defmodule LuaNox.Repo.Migrations.TotpSecretsAddLastUsedStep do
  use Ecto.Migration

  def change do
    alter table(:totp_secrets) do
      add :last_used_step, :integer
    end
  end
end
