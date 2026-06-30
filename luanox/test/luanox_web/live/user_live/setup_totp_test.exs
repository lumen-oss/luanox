defmodule LuaNoxWeb.UserLive.SetupTotpTest do
  use LuaNoxWeb.ConnCase

  import LuaNox.AccountsFixtures
  import Phoenix.LiveViewTest

  defp log_in_without_totp(conn, user) do
    token = LuaNox.Accounts.generate_user_session_token(user)

    conn
    |> init_test_session(%{})
    |> put_session(:user_token, token)
  end

  test "renders the setup page for a user without tfa", %{conn: conn} do
    user = user_fixture()
    refute LuaNox.Accounts.User.has_totp?(user)

    conn = log_in_without_totp(conn, user)
    {:ok, _lv, html} = live(conn, ~p"/setup-totp")

    assert html =~ "Set Up Two-Factor Authentication"
    assert html =~ "Verification Code"
    assert html =~ "Or enter this secret manually"
  end

  test "redirects an enrolled user to settings", %{conn: conn} do
    user = user_fixture()
    :ok = LuaNox.Accounts.TOTP.enable(user)

    conn = log_in_without_totp(conn, user)

    assert {:error, {:redirect, %{to: "/settings"}}} = live(conn, ~p"/setup-totp")
  end
end
