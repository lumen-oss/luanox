defmodule LuaNoxWeb.Plugs.RequireTotp do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if skip_path?(conn.request_path) do
      conn
    else
      user = conn.assigns.current_scope && conn.assigns.current_scope.user

      if user && !LuaNox.Accounts.User.has_totp?(user) do
        conn
        |> put_session(:user_return_to, current_path(conn))
        |> redirect(to: "/setup-totp")
        |> halt()
      else
        conn
      end
    end
  end

  @skip_paths ~w(/setup-totp /setup-totp/complete /logout)
  defp skip_path?(path), do: path in @skip_paths or String.starts_with?(path, "/auth/")
end
