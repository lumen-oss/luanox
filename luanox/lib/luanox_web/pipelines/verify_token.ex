defmodule LuaNoxWeb.Pipelines.VerifyToken do
  @moduledoc """
  This allows both the standard `Authorization: Bearer <token>` header
  and the LuaRocks-compatible `/api/1/<token>/*` URL path format.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    put_url_token_in_header(conn)
    |> Guardian.Plug.VerifyHeader.call(Guardian.Plug.VerifyHeader.init(opts))
  end

  defp put_url_token_in_header(conn) do
    case conn.params do
      %{"key" => token} when is_binary(token) and token != "" ->
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")

      _ ->
        conn
    end
  end
end
