defmodule Luxpkgs.Repo.Migrations.RestrictPackageOwnerDeletion do
  use Ecto.Migration

  # Packages are immutable and must never be destroyed by deleting their owner.
  def up do
    drop constraint(:packages, "packages_user_id_fkey")

    alter table(:packages) do
      modify :user_id, references(:users, type: :id, on_delete: :restrict)
    end
  end

  def down do
    drop constraint(:packages, "packages_user_id_fkey")

    alter table(:packages) do
      modify :user_id, references(:users, type: :id, on_delete: :delete_all)
    end
  end
end
