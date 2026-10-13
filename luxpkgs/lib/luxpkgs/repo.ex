defmodule Luxpkgs.Repo do
  use Ecto.Repo,
    otp_app: :luxpkgs,
    adapter: Ecto.Adapters.Postgres
end
