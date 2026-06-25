defmodule LuaNoxWeb.Plugs.RateLimiter do
  @moduledoc """
  Plug that enforces rate limits using Hammer.
  """

  import Plug.Conn
  alias LuaNoxWeb.RateLimit

  def init(opts), do: opts

  def call(conn, opts) do
    tier = Keyword.fetch!(opts, :tier)
    key = build_key(conn, tier)

    case RateLimit.hit(tier, key) do
      {:allow, count} ->
        {limit, _period} = Map.fetch!(RateLimit.tier_limits(), tier)

        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(max(limit - count, 0)))

      {:deny, retry_after} ->
        conn
        |> put_resp_header("retry-after", to_string(div(retry_after, 1000)))
        |> put_resp_header("x-ratelimit-limit", "0")
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_resp_content_type("application/json")
        |> send_resp(
          429,
          Jason.encode!(%{error: "rate_limit_exceeded", retry_after_ms: retry_after})
        )
        |> halt()
    end
  end

  defp build_key(conn, :general) do
    case extract_user_id(conn) do
      nil -> "ip:#{ip_to_string(conn.remote_ip)}"
      user_id -> "user:general:#{user_id}"
    end
  end

  defp build_key(conn, :search) do
    case extract_user_id(conn) do
      nil -> "ip:search:#{ip_to_string(conn.remote_ip)}"
      user_id -> "user:search:#{user_id}"
    end
  end

  defp build_key(conn, :write) do
    case extract_user_id(conn) do
      nil -> "ip:write:#{ip_to_string(conn.remote_ip)}"
      user_id -> "user:write:#{user_id}"
    end
  end

  defp extract_user_id(conn) do
    case conn.assigns do
      %{current_scope: %{user: %{id: id}}} -> id
      _ -> nil
    end
  end

  defp ip_to_string(ip) when is_tuple(ip), do: to_string(:inet.ntoa(ip))
  defp ip_to_string(ip), do: to_string(ip)
end
