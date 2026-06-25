defmodule LuaNoxWeb.Plugs.RateLimiterTest do
  use ExUnit.Case, async: false

  alias LuaNoxWeb.RateLimit
  alias LuaNoxWeb.Plugs.RateLimiter

  setup do
    on_exit(fn ->
      :ets.delete_all_objects(RateLimit)
    end)

    :ok
  end

  defp build_conn(user_id \\ nil) do
    scope =
      case user_id do
        nil -> %{user: %{id: nil}}
        id -> %{user: %{id: id}}
      end

    Plug.Test.conn(:get, "/test")
    |> Plug.Conn.assign(:current_scope, scope)
  end

  defp unique_key(base), do: "#{base}:#{System.unique_integer([:positive])}"

  describe "RateLimit.hit/2" do
    test "returns {:allow, count} when under limit" do
      key = unique_key("test:mod:allow")
      assert {:allow, 1} = RateLimit.hit(:general, key)
      assert {:allow, 2} = RateLimit.hit(:general, key)
    end

    test "returns {:deny, retry_after} when limit exceeded" do
      key = unique_key("test:mod:deny")
      for _ <- 1..10, do: RateLimit.hit(:write, key)
      assert {:deny, retry_after} = RateLimit.hit(:write, key)
      assert is_integer(retry_after)
      assert retry_after > 0
    end

    test "different tiers have independent limits" do
      key = unique_key("test:mod:tiers")

      for _ <- 1..120, do: RateLimit.hit(:general, key)
      assert {:deny, _} = RateLimit.hit(:general, key)

      assert {:allow, _} = RateLimit.hit(:search, key)
    end

    test "different keys are independent" do
      key_a = unique_key("test:mod:keya")
      key_b = unique_key("test:mod:keyb")

      for _ <- 1..10, do: RateLimit.hit(:write, key_a)
      assert {:deny, _} = RateLimit.hit(:write, key_a)
      assert {:allow, 1} = RateLimit.hit(:write, key_b)
    end
  end

  describe "RateLimiter plug" do
    test "passes through and adds rate limit headers when under limit" do
      conn = build_conn()
      result = RateLimiter.call(conn, tier: :general)

      assert result.halted == false
      limit = Plug.Conn.get_resp_header(result, "x-ratelimit-limit")
      remaining = Plug.Conn.get_resp_header(result, "x-ratelimit-remaining")
      assert limit != []
      assert remaining != []
    end

    test "returns 429 when rate limit exceeded" do
      user_id = "test_user_#{System.unique_integer([:positive])}"
      conn = build_conn(user_id)

      for _ <- 1..10, do: RateLimit.hit(:write, "user:write:#{user_id}")

      result = RateLimiter.call(conn, tier: :write)

      assert result.halted == true
      assert result.status == 429
      retry_after = Plug.Conn.get_resp_header(result, "retry-after")
      assert retry_after != []
    end

    test "identifies user by IP when no user in scope" do
      conn = build_conn(nil)
      result = RateLimiter.call(conn, tier: :general)
      assert result.halted == false
    end

    test "sets remaining to 0 on 429" do
      user_id = "test_user_#{System.unique_integer([:positive])}"
      conn = build_conn(user_id)

      for _ <- 1..10, do: RateLimit.hit(:write, "user:write:#{user_id}")

      result = RateLimiter.call(conn, tier: :write)
      remaining = Plug.Conn.get_resp_header(result, "x-ratelimit-remaining")
      assert remaining == ["0"]
    end

    test "returns JSON error body on 429" do
      user_id = "test_user_#{System.unique_integer([:positive])}"
      conn = build_conn(user_id)

      for _ <- 1..10, do: RateLimit.hit(:write, "user:write:#{user_id}")

      result = RateLimiter.call(conn, tier: :write)
      {:ok, body} = Jason.decode(result.resp_body)
      assert body["error"] == "rate_limit_exceeded"
      assert is_integer(body["retry_after_ms"])
    end
  end
end
