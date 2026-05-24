defmodule Lynxplanningpoker.Analytics do
  @moduledoc """
  First-party, cookie-free **unique daily visitor** counting.

  Visiting the site multiple times in a day counts as one visit; coming
  back tomorrow counts as one more. Instead of a cookie, each visit is
  fingerprinted in memory with a one-way SHA-256 hash of the visitor's IP,
  User-Agent, the date and a server secret — only that hash is stored
  (alongside a 2-letter country code from Cloudflare). The date is part of
  the hash input, so the same person produces a different hash every day:
  visits cannot be linked across days, only deduplicated within one. The
  IP and User-Agent themselves are never written to the database.

  No cookie, no identifier on the user's device, no third-party analytics.
  See `Lynxplanningpoker.Analytics.Visitor`.
  """
  import Ecto.Query

  alias Lynxplanningpoker.Analytics.Visitor
  alias Lynxplanningpoker.Repo

  @doc """
  Records one visit, idempotent for a given `(date, visitor)` pair: the
  first call of the day inserts the row, later calls with the same IP +
  User-Agent on the same day are no-ops.

  Required opts:
    * `:ip` — client IP as a string
    * `:user_agent` — `User-Agent` header value (or `""` if missing)
    * `:country` — ISO 3166-1 alpha-2 code, or `"XX"` when unknown

  Optional:
    * `:date` — defaults to today (UTC)
    * `:secret` — overrides the server secret used in the hash; tests pass
      this for determinism. Defaults to the endpoint's `secret_key_base`.

  Returns `{:ok, visitor}` (the row is the canonical one for the day,
  whether it was just inserted or already existed). Callers generally
  ignore the result.
  """
  def record_visit(opts) do
    ip = Keyword.fetch!(opts, :ip)
    user_agent = Keyword.fetch!(opts, :user_agent)
    country = Keyword.fetch!(opts, :country)
    date = Keyword.get(opts, :date, Date.utc_today())
    secret = Keyword.get_lazy(opts, :secret, &secret/0)

    hash = visitor_hash(date, ip, user_agent, secret)

    Repo.insert(
      %Visitor{date: date, visitor_hash: hash, country: country},
      on_conflict: :nothing,
      conflict_target: [:date, :visitor_hash]
    )
  end

  @doc "Total unique daily visitors summed across every day."
  def total_visitors do
    Repo.aggregate(Visitor, :count, :id)
  end

  @doc "Unique visitor counts as `{date, count}` tuples, most recent day first."
  def visitors_by_day do
    Visitor
    |> group_by([v], v.date)
    |> order_by([v], desc: v.date)
    |> select([v], {v.date, count(v.id)})
    |> Repo.all()
  end

  @doc "Unique visitor counts as `{country, count}` tuples, most visited first."
  def visitors_by_country do
    Visitor
    |> group_by([v], v.country)
    |> order_by([v], desc: count(v.id))
    |> select([v], {v.country, count(v.id)})
    |> Repo.all()
  end

  @doc false
  def visitor_hash(date, ip, user_agent, secret) do
    payload = "#{Date.to_iso8601(date)}|#{ip}|#{user_agent}|#{secret}"
    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  defp secret do
    :lynxplanningpoker
    |> Application.fetch_env!(LynxplanningpokerWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
