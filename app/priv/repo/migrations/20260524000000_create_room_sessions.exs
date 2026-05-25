defmodule Lynxplanningpoker.Repo.Migrations.CreateRoomSessions do
  @moduledoc """
  Records the lifespan of each Planning Poker room: one row is inserted when
  a room is created and updated with `ended_at` when the room is deleted.
  This outlives the `rooms` row itself so room-creation analytics survive
  room deletion. No personal data is stored — only the room's own UUID and
  two timestamps.
  """
  use Ecto.Migration

  def change do
    create table(:room_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, :binary_id, null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
    end

    create unique_index(:room_sessions, [:room_id])
    create index(:room_sessions, [:started_at])
  end
end
