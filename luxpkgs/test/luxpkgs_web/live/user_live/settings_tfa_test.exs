defmodule LuxpkgsWeb.UserLive.SettingsTfaTest do
  use LuxpkgsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Luxpkgs.AccountsFixtures

  alias Luxpkgs.Accounts.TOTP
  alias Luxpkgs.Accounts.User

  @secret <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20>>

  setup %{conn: conn} do
    user = user_fixture()
    :ok = TOTP.enable(user, @secret)
    codes = TOTP.generate_backup_codes(user)

    {:ok, conn: log_in_user(conn, user), user: user, codes: codes}
  end

  defp totp_code, do: NimbleTOTP.verification_code(@secret)

  test "shows the two-factor section with the backup code count", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/settings")

    assert html =~ "Two-Factor Authentication"
    assert html =~ "10 of 10 codes remaining"
  end

  test "removes two-factor authentication with a valid totp code", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    assert {:error, {:live_redirect, %{to: to}}} =
             lv
             |> form("#remove_tfa_form", %{"code" => totp_code()})
             |> render_submit()

    assert to == "/setup-totp"
    refute User.has_totp?(user)
    assert TOTP.backup_codes_remaining(user) == 0
  end

  test "removes two-factor authentication with a backup code", %{
    conn: conn,
    user: user,
    codes: [code | _]
  } do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    assert {:error, {:live_redirect, %{to: "/setup-totp"}}} =
             lv
             |> form("#remove_tfa_form", %{"code" => code})
             |> render_submit()

    refute User.has_totp?(user)
  end

  test "an invalid code does not remove two-factor authentication", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    html =
      lv
      |> form("#remove_tfa_form", %{"code" => "ZZZZZ-ZZZZZ"})
      |> render_submit()

    assert html =~ "Invalid verification code"
    assert User.has_totp?(user)
    assert TOTP.backup_codes_remaining(user) == 10
  end

  test "an empty code does not crash and does not remove two-factor authentication", %{
    conn: conn,
    user: user
  } do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    html =
      lv
      |> form("#remove_tfa_form", %{"code" => ""})
      |> render_submit()

    assert html =~ "Invalid verification code"
    assert User.has_totp?(user)
  end

  test "regenerates backup codes and invalidates the old set", %{
    conn: conn,
    user: user,
    codes: [old | _]
  } do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    html =
      lv
      |> form("#regenerate_backup_codes_form", %{"code" => totp_code()})
      |> render_submit()

    assert html =~ "Save these backup codes now"
    assert TOTP.backup_codes_remaining(user) == 10
    assert TOTP.verify(user, old) == :error
  end

  test "an invalid code does not regenerate backup codes", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    html =
      lv
      |> form("#regenerate_backup_codes_form", %{"code" => "ZZZZZ-ZZZZZ"})
      |> render_submit()

    assert html =~ "Invalid verification code"
    assert TOTP.backup_codes_remaining(user) == 10
  end

  test "throttles repeated verification attempts", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/settings")

    for _ <- 1..5 do
      lv |> form("#remove_tfa_form", %{"code" => "ZZZZZ-ZZZZZ"}) |> render_submit()
    end

    html =
      lv
      |> form("#remove_tfa_form", %{"code" => totp_code()})
      |> render_submit()

    assert html =~ "Too many attempts"
    assert User.has_totp?(user)
  end
end
