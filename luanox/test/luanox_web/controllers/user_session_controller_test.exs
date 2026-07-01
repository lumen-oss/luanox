defmodule LuaNoxWeb.UserSessionControllerTest do
  use LuaNoxWeb.ConnCase, async: true

  import LuaNox.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "DELETE /logout" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/logout")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end

    test "redirects to login if not authenticated", %{conn: conn} do
      conn = delete(conn, ~p"/logout")
      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, :user_token)
    end
  end
end
