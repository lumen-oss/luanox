defmodule LuanoxRockspecVerifierWeb.VerifyController do
  use LuanoxRockspecVerifierWeb, :controller

  alias LuanoxRockspecVerifier.Rockspec

  def verify(conn, %{
        "rockspec" => rockspec,
        "package" => expected_name,
        "version" => expected_version
      })
      when is_binary(rockspec) and
             is_binary(expected_name) and
             is_binary(expected_version) do
    case Rockspec.verify(rockspec, %{
           expected_name: expected_name,
           expected_version: expected_version
         }) do
      true ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "Rockspec is valid"
        })

      false ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Rockspec is invalid"
        })
    end
  end

  def verify(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "Invalid parameters"
    })
  end
end
