defmodule Lynxplanningpoker.Analytics.RoomSession do
  @moduledoc """
  One row per Planning Poker room ever created. `started_at` is set on
  insert; `ended_at` is filled in when the room is deleted (host leaves,
  presence cleanup, orphan cleaner, etc.). A `nil` `ended_at` means the
  room is still live.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "room_sessions" do
    field :room_id, :binary_id
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
  end
end
