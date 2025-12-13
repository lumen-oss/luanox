defmodule LuaNoxWeb.LuarocksApiController do
  alias LuaNox.Guardian
  use LuaNoxWeb, :controller

  action_fallback(LuaNoxWeb.FallbackController)

  def tool_version(conn, _params) do
    json(conn, %{
      "version" => "1.0.0"
    })
  end

  def status(conn, %{"api_key" => api_key}) do
    case validate_api_key(api_key) do
      {:ok, _claims} ->
        send_resp(conn, :ok, "OK")

      :error ->
        conn
        |> put_status(:unauthorized)
    end
  end

  defp validate_api_key(api_key) do
    case Guardian.decode_and_verify(api_key, %{iss: "luanox", aud: "luanox", typ: "access"}) do
      {:ok, claims} ->
        if LuaNox.RevokedKeys.is_revoked?(api_key) do
          :error
        else
          {:ok, claims}
        end

      {:error, _reason} ->
        :error
    end
  end
end
