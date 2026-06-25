defmodule LuaNox.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LuaNoxWeb.Telemetry,
      LuaNox.Repo,
      {DNSCluster, query: Application.get_env(:luanox, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LuaNox.PubSub},
      {LuaNoxWeb.RateLimit,
       clean_period: :timer.minutes(5)},
      {Cachex, name: :search_cache, limit: 1_000},
      LuaNoxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LuaNox.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LuaNoxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
