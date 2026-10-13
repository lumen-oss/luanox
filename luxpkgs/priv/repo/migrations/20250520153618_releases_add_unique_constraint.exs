defmodule Luxpkgs.Repo.Migrations.ReleasesAddUniqueConstraint do
  use Ecto.Migration

  def change do
    create unique_index(:releases, [:package_id, :version], name: :unique_package_version)
  end
end
