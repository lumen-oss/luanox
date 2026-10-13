defmodule Luxpkgs.Repo.Migrations.AddUserOauthInfo do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :provider, :string, null: false
      add :username, :string, null: false
      add :aka, :string
    end

    create unique_index(:users, [:provider, :username])
  end
end
