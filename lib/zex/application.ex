defmodule Zex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ZexWeb.Telemetry,
      Zex.Repo,
      {DNSCluster, query: Application.get_env(:zex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Zex.PubSub},
      # Start a worker by calling: Zex.Worker.start_link(arg)
      # {Zex.Worker, arg},
      Zex.GameCache,
      # Start to serve requests, typically the last entry
      ZexWeb.Endpoint,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Zex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ZexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
