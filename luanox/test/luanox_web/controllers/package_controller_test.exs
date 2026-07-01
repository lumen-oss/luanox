defmodule LuaNoxWeb.PackageControllerTest do
  use LuaNoxWeb.ConnCase

  import LuaNox.PackagesFixtures

  setup %{conn: conn} = context do
    user = LuaNox.AccountsFixtures.user_fixture()
    scope = LuaNox.Accounts.Scope.for_user(user)
    conn = conn |> authenticate_api_user(user) |> put_req_header("accept", "application/json")
    {:ok, conn: conn, user: user, scope: scope}
  end

  describe "index" do
    test "lists packages with query param", %{conn: conn, scope: scope} do
      package_fixture(scope)
      conn = get(conn, ~p"/api/packages?query=pkg")
      assert json_response(conn, 200)["data"]
    end

    test "returns 400 without query param", %{conn: conn} do
      conn = get(conn, ~p"/api/packages")
      assert json_response(conn, 400)
    end
  end

  describe "create package" do
    test "renders package when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/packages", package: %{name: "my-pkg", summary: "A package", description: "Details"})
      assert %{"name" => "my-pkg"} = json_response(conn, 201)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/packages", package: %{name: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "show package" do
    test "returns the package", %{conn: conn, scope: scope} do
      package_fixture(scope, %{name: "show-pkg"})
      conn = get(conn, ~p"/api/packages/show-pkg")
      assert %{"name" => "show-pkg"} = json_response(conn, 200)["data"]
    end

    test "returns 404 for unknown package", %{conn: conn} do
      conn = get(conn, ~p"/api/packages/nonexistent")
      assert json_response(conn, 404)
    end
  end
end
