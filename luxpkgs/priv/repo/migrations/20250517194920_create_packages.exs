defmodule Luxpkgs.Repo.Migrations.CreatePackages do
  use Ecto.Migration

  def change do
    create table(:packages) do
      add :name, :string, null: false
      add :summary, :text
      add :description, :text
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:packages, [:name])
    create index(:packages, [:user_id])
  end
end
