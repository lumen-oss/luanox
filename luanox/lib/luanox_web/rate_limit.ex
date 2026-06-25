defmodule LuaNoxWeb.RateLimit do
  use Hammer, backend: :ets

  def tier_limits, do: %{
    general: {120, 60_000},
    search: {100, 3_600_000},
    write: {10, 3_600_000}
  }

  def hit(tier, key) do
    {limit, period} = Map.fetch!(__MODULE__.tier_limits(), tier)
    __MODULE__.hit(key, period, limit)
  end
end
