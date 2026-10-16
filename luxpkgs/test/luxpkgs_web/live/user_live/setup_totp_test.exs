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

    conn = log_in_without_totp(conn, user)
    {:ok, _lv, _html} = live(conn, ~p"/setup-totp")
    secret = pending_secret(user)
    code = NimbleTOTP.verification_code(Base.decode32!(secret, padding: false))

    conn = post(conn, ~p"/setup-totp/complete", %{"code" => code})

    assert redirected_to(conn) == ~p"/settings"
    assert Luxpkgs.Accounts.TOTP.backup_codes_remaining(user) == 10

    {:ok, lv, html} = live(conn, ~p"/settings")
    assert html =~ "Save these backup codes now"
    assert has_element?(lv, "input#tfa-toggle[checked]")
    refute has_element?(lv, "input#account-toggle[checked]")

    {:ok, _lv, html} = live(conn, ~p"/settings")
    refute html =~ "Save these backup codes now"
  end

  test "rejects an enrolled user and keeps the existing secret", %{conn: conn} do
    user = user_fixture()
    original = NimbleTOTP.secret()
    :ok = Luxpkgs.Accounts.TOTP.enable(user, original)

    attacker_secret = NimbleTOTP.secret()

    conn =
      conn
      |> log_in_without_totp(user)
      |> post(~p"/setup-totp/complete", %{
        "secret" => Base.encode32(attacker_secret, padding: false),
        "code" => NimbleTOTP.verification_code(attacker_secret)
      })

    assert redirected_to(conn) == ~p"/settings"
    assert Luxpkgs.Accounts.TOTP.secret(user) == original
    assert Luxpkgs.Accounts.TOTP.backup_codes_remaining(user) == 0
    assert Cachex.get(:totp_backup_codes, user.id) == {:ok, nil}
  end

  test "ignores a client-supplied secret the server did not issue", %{conn: conn} do
    user = user_fixture()

    conn = log_in_without_totp(conn, user)
    {:ok, _lv, _html} = live(conn, ~p"/setup-totp")
    secret = pending_secret(user)

    attacker_secret = NimbleTOTP.secret()

    conn =
      post(conn, ~p"/setup-totp/complete", %{
        "secret" => Base.encode32(attacker_secret, padding: false),
        "code" => NimbleTOTP.verification_code(attacker_secret)
      })

    assert redirected_to(conn) == ~p"/setup-totp"
    refute Luxpkgs.Accounts.User.has_totp?(user)
    assert Cachex.get(:totp_setup, user.id) == {:ok, secret}
  end

  test "reuses the pending secret when a retry is submitted", %{conn: conn} do
    user = user_fixture()
    conn = log_in_without_totp(conn, user)

    {:ok, _lv, _html} = live(conn, ~p"/setup-totp")
    secret = pending_secret(user)
    code = NimbleTOTP.verification_code(Base.decode32!(secret, padding: false))
    wrong = if code == "000000", do: "111111", else: "000000"

    conn = post(conn, ~p"/setup-totp/complete", %{"code" => wrong})
    assert redirected_to(conn) == ~p"/setup-totp"

    {:ok, _lv, _html} = live(conn, ~p"/setup-totp")
    assert pending_secret(user) == secret
  end

  defp pending_secret(user) do
    {:ok, secret} = Cachex.get(:totp_setup, user.id)
    secret
  end
end
