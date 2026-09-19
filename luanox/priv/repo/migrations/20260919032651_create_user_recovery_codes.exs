defmodule LuaNox.Repo.Migrations.CreateUserRecoveryCodes do
  use Ecto.Migration

  def change do
    create table(:user_recovery_codes) do
      add :user_id, references(:users, type: :id, on_delete: :delete_all), null: false
      add :code_hash, :string, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:user_recovery_codes, [:user_id])
  end
end
