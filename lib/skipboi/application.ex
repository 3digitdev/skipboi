defmodule Skipboi.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      SkipboiWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:skipboi, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Skipboi.PubSub},
      Skipboi.Games,
      # Start to serve requests, typically the last entry
      SkipboiWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Skipboi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    SkipboiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
