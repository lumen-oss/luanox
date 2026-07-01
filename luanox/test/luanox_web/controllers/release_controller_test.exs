defmodule LuaNoxWeb.ReleaseControllerTest do
  use LuaNoxWeb.ConnCase

  import LuaNox.PackagesFixtures

  setup %{conn: conn} do
    user = LuaNox.AccountsFixtures.user_fixture()
    scope = LuaNox.Accounts.Scope.for_user(user)
    conn = conn |> authenticate_api_user(user) |> put_req_header("accept", "application/json")
    {:ok, conn: conn, user: user, scope: scope}
  end

  describe "show release" do
    test "returns the release as file download", %{conn: conn, scope: scope} do
      release = release_fixture(scope)
      conn = get(conn, ~p"/api/releases/#{release.id}")
      assert conn.status == 200
    end

    test "returns 404 for unknown release", %{conn: conn} do
      conn = get(conn, ~p"/api/releases/999999")
      assert json_response(conn, 404)
    end
  end
end
