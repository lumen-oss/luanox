defmodule LuxpkgsWeb.UserLive.SetupTotpTest do
  use LuxpkgsWeb.ConnCase

  import Luxpkgs.AccountsFixtures
  import Phoenix.LiveViewTest

  defp log_in_without_totp(conn, user) do
    token = Luxpkgs.Accounts.generate_user_session_token(user)

    conn
    |> init_test_session(%{})
    |> put_session(:user_token, token)
  end

  test "renders the setup page for a user without tfa", %{conn: conn} do
    user = user_fixture()
    refute Luxpkgs.Accounts.User.has_totp?(user)

    conn = log_in_without_totp(conn, user)
    {:ok, _lv, html} = live(conn, ~p"/setup-totp")

    assert html =~ "Set Up Two-Factor Authentication"
    assert html =~ "Verification Code"
    assert html =~ "Or enter this secret manually"
  end

  test "redirects an enrolled user to settings", %{conn: conn} do
    user = user_fixture()
    :ok = Luxpkgs.Accounts.TOTP.enable(user)

    conn = log_in_without_totp(conn, user)

    assert {:error, {:redirect, %{to: "/settings"}}} = live(conn, ~p"/setup-totp")
  end

  test "generates backup codes on completion and reveals them once", %{conn: conn} do
    user = user_fixture()
    secret = NimbleTOTP.secret()
    code = NimbleTOTP.verification_code(secret)

    conn =
      conn
      |> log_in_without_totp(user)
      |> post(~p"/setup-totp/complete", %{
        "secret" => Base.encode32(secret, padding: false),
        "code" => code
      })

    assert redirected_to(conn) == ~p"/settings"
    assert Luxpkgs.Accounts.TOTP.backup_codes_remaining(user) == 10

    {:ok, lv, html} = live(conn, ~p"/settings")
    assert html =~ "Save these backup codes now"
    assert has_element?(lv, "input#tfa-toggle[checked]")
    refute has_element?(lv, "input#account-toggle[checked]")

    {:ok, _lv, html} = live(conn, ~p"/settings")
    refute html =~ "Save these backup codes now"
  end
end
