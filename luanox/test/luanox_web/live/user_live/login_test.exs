defmodule LuaNoxWeb.UserLive.LoginTest do
  use LuaNoxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LuaNox.AccountsFixtures

  describe "login page" do
    test "renders login page with OAuth provider", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Choose an OAuth Provider"
      assert html =~ "GitHub"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows reauthentication message when logged in", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "You need to reauthenticate"
    end
  end

  describe "two-factor challenge" do
    test "renders the challenge when a user id is pending in session", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> init_test_session(%{pending_2fa_user_id: user.id})
        |> live(~p"/login/totp")

      assert html =~ "Two-Factor Authentication"
      assert html =~ "recovery code"
    end

    test "redirects to login when no pending user", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/login/totp")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "logs in with a valid TOTP code", %{conn: conn} do
      user = user_fixture()
      secret = LuaNox.Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, user} = LuaNox.Accounts.enable_totp(user, secret, code)

      conn =
        conn
        |> init_test_session(%{pending_2fa_user_id: user.id})

      conn = post(conn, ~p"/login/totp", %{"user_id" => user.id, "code" => code})
      assert redirected_to(conn) == ~p"/"
    end

    test "logs in with a valid recovery code", %{conn: conn} do
      user = user_fixture()
      secret = LuaNox.Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, user} = LuaNox.Accounts.enable_totp(user, secret, code)
      [recovery | _] = LuaNox.Accounts.generate_recovery_codes(user)

      conn =
        conn
        |> init_test_session(%{pending_2fa_user_id: user.id})

      conn = post(conn, ~p"/login/totp", %{"user_id" => user.id, "code" => recovery})
      assert redirected_to(conn) == ~p"/"
    end

    test "rejects an invalid code with an error flash", %{conn: conn} do
      user = user_fixture()
      secret = LuaNox.Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, _user} = LuaNox.Accounts.enable_totp(user, secret, code)

      conn =
        conn
        |> init_test_session(%{pending_2fa_user_id: user.id})

      conn = post(conn, ~p"/login/totp", %{"user_id" => user.id, "code" => "000000"})
      assert redirected_to(conn) == ~p"/login/totp"
      assert get_flash(conn, :error) =~ "Invalid code"
    end

    test "rejects an unknown user", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{pending_2fa_user_id: -1})

      conn = post(conn, ~p"/login/totp", %{"user_id" => -1, "code" => "000000"})
      assert redirected_to(conn) == ~p"/login"
    end
  end
end
