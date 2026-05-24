defmodule Lynxplanningpoker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Resolve hostnames via the OS resolver — Fly.io's IPv6-only nameserver
    # breaks Erlang's built-in DNS client. See Lynxplanningpoker.Release.
    :inet_db.set_lookup([:native])

    children =
      [
        LynxplanningpokerWeb.Telemetry,
        Lynxplanningpoker.Repo,
        {DNSCluster,
         query: Application.get_env(:lynxplanningpoker, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Lynxplanningpoker.PubSub},
        {Lynxplanningpoker.RateLimit, [clean_period: :timer.minutes(10)]},
        Lynxplanningpoker.Presence
      ] ++
        room_cleaner_child() ++
        [
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

  defp room_cleaner_child do
    cfg = Application.get_env(:lynxplanningpoker, :room_cleaner, [])

    if Keyword.get(cfg, :enabled, false) do
      opts = Keyword.take(cfg, [:sweep_interval, :max_idle])
      [{Lynxplanningpoker.Rooms.Cleaner, opts}]
    else
      []
    end
  end
end
