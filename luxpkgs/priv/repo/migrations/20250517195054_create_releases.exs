defmodule Luxpkgs.Repo.Migrations.CreateReleases do
  use Ecto.Migration

  def change do
    create table(:releases) do
      add :version, :string
      add :rockspec_path, :text
      add :package_id, references(:packages, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:releases, [:package_id])
  end
end
