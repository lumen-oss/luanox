defmodule LuxpkgsWeb.TfaEnforcementTest do
  use LuxpkgsWeb.ConnCase

  import Luxpkgs.AccountsFixtures

  alias Luxpkgs.Accounts.TOTP

  @secret <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20>>

  setup %{conn: conn} do
    user = user_fixture()
    :ok = TOTP.enable(user, @secret)
    codes = TOTP.generate_backup_codes(user)

    path = Path.join(System.tmp_dir!(), "tfa-#{System.unique_integer([:positive])}.rockspec")
    File.write!(path, "return { }")
    on_exit(fn -> File.rm(path) end)

    upload = %Plug.Upload{path: path, filename: "pkg-1.0-1.rockspec", content_type: "text/plain"}

    conn = put_req_header(conn, "accept", "application/json")

    {:ok, conn: conn, user: user, upload: upload, codes: codes}
  end

  defp jwt(user, require_tfa) do
    {:ok, token, _claims} =
      Luxpkgs.Guardian.encode_and_sign(user, %{
        "allowed_packages" => nil,
        "write_restriction" => false,
        "require_tfa" => require_tfa
      })

    token
  end

  defp valid_code, do: NimbleTOTP.verification_code(@secret)

  describe "POST /api/1/:key/upload" do
    test "blocks a key that requires tfa and sends no code", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn = post(conn, "/api/1/#{jwt(user, true)}/upload", %{"rockspec_file" => upload})

      assert json_response(conn, 403)["two_factor_required"] == true
    end

    test "blocks a key that requires tfa and sends a wrong code", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn =
        post(conn, "/api/1/#{jwt(user, true)}/upload", %{
          "rockspec_file" => upload,
          "tfa_code" => "abcdef"
        })

      assert json_response(conn, 403)["two_factor_required"] == true
    end

    test "lets a key that requires tfa through with a valid code", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn =
        post(conn, "/api/1/#{jwt(user, true)}/upload", %{
          "rockspec_file" => upload,
          "tfa_code" => valid_code()
        })

      assert conn.status == 503
    end

    test "does not ask for a code when the key opts out", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn = post(conn, "/api/1/#{jwt(user, false)}/upload", %{"rockspec_file" => upload})

      assert conn.status == 503
    end

    test "accepts a backup code once and rejects its reuse", %{
      conn: conn,
      user: user,
      upload: upload,
      codes: [code | _]
    } do
      path = "/api/1/#{jwt(user, true)}/upload"
      params = %{"rockspec_file" => upload, "tfa_code" => code}

      first = post(conn, path, params)
      assert first.status == 503

      second = post(build_conn() |> put_req_header("accept", "application/json"), path, params)

      assert json_response(second, 403)["two_factor_required"] == true
    end

    test "treats a token with no require_tfa claim as requiring tfa", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      {:ok, token, _claims} =
        Luxpkgs.Guardian.encode_and_sign(user, %{
          "allowed_packages" => nil,
          "write_restriction" => false
        })

      conn = post(conn, "/api/1/#{token}/upload", %{"rockspec_file" => upload})

      assert json_response(conn, 403)["two_factor_required"] == true
    end

    test "rate limits attempts, then rejects even a valid code", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      path = "/api/1/#{jwt(user, true)}/upload"

      for _ <- 1..5 do
        attempt = post(conn, path, %{"rockspec_file" => upload, "tfa_code" => "000000"})
        assert json_response(attempt, 403)["two_factor_required"] == true
      end

      blocked =
        post(build_conn() |> put_req_header("accept", "application/json"), path, %{
          "rockspec_file" => upload,
          "tfa_code" => valid_code()
        })

      assert json_response(blocked, 403)["two_factor_required"] == true
    end
  end

  describe "POST /api/releases" do
    test "blocks a key that requires tfa and sends no code", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt(user, true)}")
        |> post(~p"/api/releases", %{
          "package" => "pkg",
          "version" => "1.0-1",
          "rockspec" => upload
        })

      assert json_response(conn, 403)["two_factor_required"] == true
    end

    test "rejects a wrong code", %{conn: conn, user: user, upload: upload} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt(user, true)}")
        |> post(~p"/api/releases", %{
          "package" => "pkg",
          "version" => "1.0-1",
          "rockspec" => upload,
          "tfa_code" => "abcdef"
        })

      assert json_response(conn, 401)["errors"] == ["Invalid verification code"]
    end

    test "passes the tfa gate with a valid code", %{conn: conn, user: user, upload: upload} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt(user, true)}")
        |> post(~p"/api/releases", %{
          "package" => "pkg",
          "version" => "1.0-1",
          "rockspec" => upload,
          "tfa_code" => valid_code()
        })

      assert conn.status == 404
    end

    test "does not ask for a code when the key opts out", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt(user, false)}")
        |> post(~p"/api/releases", %{
          "package" => "pkg",
          "version" => "1.0-1",
          "rockspec" => upload
        })

      assert conn.status == 404
    end

    test "rate limits attempts, then rejects even a valid code", %{
      conn: conn,
      user: user,
      upload: upload
    } do
      conn = put_req_header(conn, "authorization", "Bearer #{jwt(user, true)}")

      for _ <- 1..5 do
        attempt =
          post(conn, ~p"/api/releases", %{
            "package" => "pkg",
            "version" => "1.0-1",
            "rockspec" => upload,
            "tfa_code" => "000000"
          })

        assert json_response(attempt, 401)["errors"] == ["Invalid verification code"]
      end

      blocked =
        post(conn, ~p"/api/releases", %{
          "package" => "pkg",
          "version" => "1.0-1",
          "rockspec" => upload,
          "tfa_code" => valid_code()
        })

      assert json_response(blocked, 403)["two_factor_required"] == true
    end
  end
end
