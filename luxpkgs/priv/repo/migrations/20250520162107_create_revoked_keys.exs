defmodule Luxpkgs.Repo.Migrations.CreateRevokedKeys do
  use Ecto.Migration

  def change do
    create table(:revoked_keys) do
      add :jti, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:revoked_keys, [:jti])
  end
end
