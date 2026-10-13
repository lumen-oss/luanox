defmodule LuxpkgsWeb.UserAuthController do
  use LuxpkgsWeb, :controller

  alias LuxpkgsWeb.UserAuth

  def log_out_user(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
