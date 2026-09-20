defmodule LuaNoxWeb.UserLive.SettingsTest do
  use LuaNoxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LuaNox.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/settings")

      assert html =~ "Settings"
      assert html =~ "Manage your profile and account preferences"
    end

    test "updates the user's bio", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      lv
      |> form("#bio_form", user: %{bio: "Building rocks"})
      |> render_submit()

      assert LuaNox.Accounts.get_user!(user.id).bio == "Building rocks"
    end

    test "renders a bio character counter", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      assert html =~ "0/160"
      assert html =~ ~s(phx-hook="CharacterCounter")
      assert html =~ ~s(data-counter-target="bio-count")
    end

    test "strips links from the submitted bio", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      lv
      |> form("#bio_form", user: %{bio: "Visit https://evil.example and evil.com"})
      |> render_submit()

      bio = LuaNox.Accounts.get_user!(user.id).bio

      refute bio =~ "https://evil.example"
      refute bio =~ "evil.com"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/settings")
        |> follow_redirect(conn, ~p"/login")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "two-factor authentication" do
    test "renders enable button when 2FA is disabled", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/settings")

      assert html =~ "Enable 2FA"
      assert html =~ "Disabled"
    end

    test "enable_2fa shows QR code and secret", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      html = lv |> element("button[phx-click=\"enable_2fa\"]") |> render_click()
      assert html =~ ~s(<img)
      assert html =~ "data:image/png;base64"
    end

    test "qr_otpauth_uri uses the username as label and the real secret", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      html = lv |> element("button[phx-click=\"enable_2fa\"]") |> render_click()

      secret =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("code")
        |> Floki.text()
        |> String.replace(~r/[^A-Z2-7]/, "")

      uri = LuaNoxWeb.UserLive.Settings.qr_otpauth_uri(secret, user.username)
      parsed = URI.parse(uri)

      assert parsed.scheme == "otpauth"
      assert parsed.host == "totp"
      assert parsed.path == "/Luanox:#{user.username}"
      assert parsed.query |> URI.decode_query() |> Map.get("secret") == secret
    end

    test "confirm_2fa with valid code enables 2FA and shows recovery codes", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      html = lv |> element("button[phx-click=\"enable_2fa\"]") |> render_click()

      secret =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("code")
        |> Floki.text()
        |> String.replace(~r/[^A-Z2-7]/, "")
      code = NimbleTOTP.verification_code(Base.decode32!(secret))

      html =
        lv
        |> form("form[phx-submit=\"confirm_2fa\"]", code: code)
        |> render_submit()

      assert html =~ "Recovery Codes"
      assert LuaNox.Accounts.totp_enabled?(LuaNox.Accounts.get_user!(user.id))
    end

    test "confirm_2fa with invalid code shows error", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/settings")

      lv |> element("button[phx-click=\"enable_2fa\"]") |> render_click()

      html =
        lv
        |> form("form[phx-submit=\"confirm_2fa\"]", code: "000000")
        |> render_submit()

      assert html =~ "Invalid code"
    end

    test "renders disable button when 2FA is enabled", %{conn: conn} do
      user = user_fixture()
      secret = LuaNox.Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, user} = LuaNox.Accounts.enable_totp(user, secret, code)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      assert html =~ "Disable 2FA"
      assert html =~ "Enabled"
    end

    test "disable_2fa with valid code disables 2FA", %{conn: conn} do
      user = user_fixture()
      secret = LuaNox.Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, user} = LuaNox.Accounts.enable_totp(user, secret, code)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      html =
        lv
        |> form("form[phx-submit=\"disable_2fa\"]", code: NimbleTOTP.verification_code(Base.decode32!(secret)))
        |> render_submit()

      assert html =~ "Two-factor authentication disabled"
      refute LuaNox.Accounts.totp_enabled?(LuaNox.Accounts.get_user!(user.id))
    end
  end
end
