defmodule LuaNoxWeb.PackageLive.ShowTest do
  use LuaNoxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders not found for an unknown package", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/package/does-not-exist")

    assert html =~ "Package not found"
  end
end