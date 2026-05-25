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

  alias Lynxplanningpoker.Analytics.RoomSession
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

  @doc """
  Records that a room was just created. Idempotent per `room_id` — calling
  twice for the same room is a no-op.

  Optional `:now` overrides the timestamp; tests pass it for determinism.
  Defaults to `DateTime.utc_now/0` truncated to seconds.
  """
  def record_room_created(room_id, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &utc_now/0)

    Repo.insert(
      %RoomSession{room_id: room_id, started_at: now},
      on_conflict: :nothing,
      conflict_target: [:room_id]
    )
  end

  @doc """
  Marks a previously-created room as ended. No-op if the room was never
  recorded as created or has already been ended.

  Optional `:now` overrides the timestamp; tests pass it for determinism.
  """
  def record_room_ended(room_id, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &utc_now/0)

    {updated, _} =
      from(s in RoomSession, where: s.room_id == ^room_id and is_nil(s.ended_at))
      |> Repo.update_all(set: [ended_at: now])

    {:ok, updated}
  end

  @doc "Total number of rooms ever created."
  def total_rooms do
    Repo.aggregate(RoomSession, :count, :id)
  end

  @doc "Room counts as `{date, count}` tuples by `started_at` date, most recent day first."
  def rooms_by_day do
    RoomSession
    |> group_by([s], fragment("date(?)", s.started_at))
    |> order_by([s], desc: fragment("date(?)", s.started_at))
    |> select([s], {fragment("date(?)", s.started_at), count(s.id)})
    |> Repo.all()
  end

  @doc """
  Average duration in seconds across rooms that have ended. Returns `nil`
  when no room has ended yet.
  """
  def average_room_duration_seconds do
    query =
      from s in RoomSession,
        where: not is_nil(s.ended_at),
        select: avg(fragment("EXTRACT(EPOCH FROM (? - ?))", s.ended_at, s.started_at))

    case Repo.one(query) do
      nil -> nil
      %Decimal{} = avg -> avg |> Decimal.round(2) |> Decimal.to_float()
    end
  end

  defp utc_now, do: DateTime.utc_now() |> DateTime.truncate(:second)

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
