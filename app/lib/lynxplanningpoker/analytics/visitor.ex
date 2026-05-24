defmodule Lynxplanningpoker.Analytics.Visitor do
  @moduledoc """
  One row per unique daily visitor.

  `visitor_hash` is a SHA-256 over the visitor's IP, User-Agent, the date
  and a server secret. The inputs are never stored, and because the date is
  one of the inputs the same person produces a different hash every day —
  visits cannot be linked across days, only deduplicated within one. The
  count of rows for a given `date` is the number of unique visitors that
  day. `country` is an ISO 3166-1 alpha-2 code (or `"XX"` when unknown),
  taken from the visitor's first request of the day.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "visitors" do
    field :date, :date
    field :visitor_hash, :string
    field :country, :string
  end
end
