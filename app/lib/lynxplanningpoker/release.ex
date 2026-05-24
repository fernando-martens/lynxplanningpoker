defmodule Lynxplanningpoker.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :lynxplanningpoker

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Force Erlang to resolve hostnames through the OS resolver. Fly.io's
    # nameserver answers only over IPv6 and Erlang's built-in DNS client
    # returns :nxdomain for external hosts (e.g. the RDS endpoint). This must
    # run in the real VM — setting it in runtime.exs has no effect because the
    # config provider runs in a throwaway VM that is rebooted before migrate.
    :inet_db.set_lookup([:native])

    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
