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
end
