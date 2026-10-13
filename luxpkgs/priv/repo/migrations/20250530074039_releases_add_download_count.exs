defmodule Luxpkgs.Repo.Migrations.ReleasesAddDownloadCount do
  use Ecto.Migration

  def change do
    alter table(:releases) do
      add :download_count, :integer, default: 0, null: false
    end
  end
end
