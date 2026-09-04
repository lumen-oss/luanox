defmodule LuaNox.Repo.Migrations.AddUsersBio do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :bio, :string
    end
  end
end
