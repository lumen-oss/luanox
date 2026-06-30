defmodule LuaNoxWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint LuaNoxWeb.Endpoint
      use LuaNoxWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import LuaNoxWeb.ConnCase
    end
  end

  setup tags do
    LuaNox.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def register_and_log_in_user(%{conn: conn} = context) do
    user = LuaNox.AccountsFixtures.user_fixture()
    scope = LuaNox.Accounts.Scope.for_user(user)
    opts = context |> Map.take([:token_authenticated_at]) |> Enum.into([])
    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  # Two-factor authentication is mandatory, so a logged-in browser user is
  # always enrolled. Enable a TOTP secret for the test user if it has none.
  def log_in_user(conn, user, opts \\ []) do
    unless LuaNox.Accounts.User.has_totp?(user) do
      :ok = LuaNox.Accounts.TOTP.enable(user)
    end

    token = LuaNox.Accounts.generate_user_session_token(user)
    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  def authenticate_api_user(conn, user) do
    {:ok, jwt, _claims} =
      LuaNox.Guardian.encode_and_sign(user, %{
        "allowed_packages" => nil,
        "write_restriction" => false,
        "require_tfa" => false
      })

    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{jwt}")
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    LuaNox.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end
