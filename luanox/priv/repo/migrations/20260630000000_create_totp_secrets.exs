defmodule LuaNox.Repo.Migrations.CreateTotpSecrets do
  use Ecto.Migration

  def change do
    create table(:totp_secrets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :secret, :binary, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:totp_secrets, [:user_id])
  end
end
