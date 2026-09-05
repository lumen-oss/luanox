defmodule LuaNoxWeb.ErrorHTMLTest do
  use LuaNoxWeb.ConnCase, async: true

  test "renders the 404 page", %{conn: conn} do
    conn = get(conn, "/nonexistent")

    assert html_response(conn, 404) =~ "does not exist"
  end

  test "renders the 500 template" do
    rendered = apply(LuaNoxWeb.ErrorHTML, :"500", [%{}])

    assert rendered.static |> Enum.join() =~ "Something went wrong"
  end
end
