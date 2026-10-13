defmodule Luxpkgs.Repo.Migrations.CreateTotpBackupCodes do
  use Ecto.Migration

  def change do
    create table(:totp_backup_codes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :code_hash, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:totp_backup_codes, [:user_id])
  end
end
