defmodule LuanoxRockspecVerifier.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LuanoxRockspecVerifierWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:luanox_rockspec_verifier, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LuanoxRockspecVerifier.PubSub},
      # Start a worker by calling: LuanoxRockspecVerifier.Worker.start_link(arg)
      # {LuanoxRockspecVerifier.Worker, arg},
      # Start to serve requests, typically the last entry
      LuanoxRockspecVerifierWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LuanoxRockspecVerifier.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LuanoxRockspecVerifierWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
