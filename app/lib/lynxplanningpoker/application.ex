defmodule Lynxplanningpoker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LynxplanningpokerWeb.Telemetry,
      Lynxplanningpoker.Repo,
      {DNSCluster, query: Application.get_env(:lynxplanningpoker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Lynxplanningpoker.PubSub},
      {Lynxplanningpoker.RateLimit, [clean_period: :timer.minutes(10)]},
      Lynxplanningpoker.Presence,
      # Start a worker by calling: Lynxplanningpoker.Worker.start_link(arg)
      # {Lynxplanningpoker.Worker, arg},
      # Start to serve requests, typically the last entry
      LynxplanningpokerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lynxplanningpoker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LynxplanningpokerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
