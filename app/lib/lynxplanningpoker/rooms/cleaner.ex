defmodule Lynxplanningpoker.Rooms.Cleaner do
  @moduledoc """
  Periodically deletes orphaned rooms (rooms with no users) that have been
  idle longer than the configured `max_idle` window.

  Hosts who close the browser before any presence/leave hook fires leave the
  room and host user behind. The presence-diff cleanup handles most cases,
  but if every client disconnects unexpectedly (network drop, crash, full
  process tree teardown), the room is never explicitly deleted. This sweeper
  is the safety net.

  Defaults: sweeps every 10 minutes, deletes rooms idle > 2 hours.
  """
  use GenServer

  require Logger

  alias Lynxplanningpoker.Rooms

  @default_sweep_interval :timer.minutes(10)
  @default_max_idle :timer.hours(2)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    state = %{
      sweep_interval: Keyword.get(opts, :sweep_interval, @default_sweep_interval),
      max_idle: Keyword.get(opts, :max_idle, @default_max_idle)
    }

    schedule_sweep(state.sweep_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    deleted = Rooms.delete_orphaned_rooms(state.max_idle)

    if deleted > 0 do
      Logger.info("[rooms.cleaner] deleted #{deleted} orphaned room(s)")
    end

    schedule_sweep(state.sweep_interval)
    {:noreply, state}
  end

  defp schedule_sweep(interval) do
    Process.send_after(self(), :sweep, interval)
  end
end
