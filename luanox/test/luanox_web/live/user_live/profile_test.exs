defmodule LuaNoxWeb.UserLive.ProfileTest do
  use LuaNoxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LuaNox.AccountsFixtures
  import LuaNox.PackagesFixtures

  describe "Public profile page" do
    test "renders the user's profile with their packages", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      package = package_fixture(scope, %{name: "my_package"})
      release = release_fixture(scope, package)
      LuaNox.Repo.update_all(LuaNox.Packages.Release, set: [download_count: 1200])

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.username}")

      assert html =~ user.username
      assert html =~ "my_package"
      assert html =~ "1.2K"
      assert html =~ to_string(release.version)
    end

    test "does not expose the user's email", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.username}")

      refute html =~ user.email
    end

    test "renders an empty state when the user has no packages", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.username}")

      assert html =~ "has not published any packages yet"
    end

    test "redirects home for an unknown user", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/users/does-not-exist")

      assert {:redirect, %{to: to, flash: flash}} = redirect
      assert to == ~p"/"
      assert %{"error" => "User not found"} = flash
    end

    test "paginates the user's packages", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)

      for i <- 1..13 do
        package_fixture(scope, %{name: "pkg_#{i}"})
      end

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.username}")

      assert html =~ "Showing 12 of 13 packages"

      {:ok, _lv, page2} = live(conn, ~p"/users/#{user.username}?page=2")

      assert page2 =~ "Showing 1 of 13 packages"
    end

    test "sorts packages by name", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)

      for name <- ~w(zeta_pkg alpha_pkg bravo_pkg) do
        package_fixture(scope, %{name: name})
      end

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.username}?sort=name")

      alpha = :binary.match(html, "alpha_pkg")
      bravo = :binary.match(html, "bravo_pkg")
      zeta = :binary.match(html, "zeta_pkg")

      assert elem(alpha, 0) < elem(bravo, 0)
      assert elem(bravo, 0) < elem(zeta, 0)
    end
  end

  describe "Package show page" do
    test "links the author card to the profile page", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      package = package_fixture(scope, %{name: "author_pkg"})
      release_fixture(scope, package)

      {:ok, _lv, html} = live(conn, ~p"/package/author_pkg")

      assert html =~ ~p"/users/#{user.username}"
    end
  end
end
