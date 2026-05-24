defmodule Lynxplanningpoker.Rooms.CleanerTest do
  use Lynxplanningpoker.DataCase, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Lynxplanningpoker.Repo
  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Rooms.Cleaner
  alias Lynxplanningpoker.Rooms.Room

  # Same backdating trick as in rooms_test, kept local to avoid coupling.
  defp backdate_room!(room, seconds_ago) do
    then = DateTime.utc_now() |> DateTime.add(-seconds_ago, :second) |> DateTime.truncate(:second)
    Repo.update_all(from(r in Room, where: r.id == ^room.id), set: [updated_at: then])
    Repo.get!(Room, room.id)
  end

  defp start_cleaner!(opts) do
    # Use a unique name per test so processes from different tests don't clash
    # under async: false (multiple cases still share the BEAM).
    name = :"cleaner_#{System.unique_integer([:positive])}"

    pid =
      start_supervised!(
        Supervisor.child_spec({Cleaner, Keyword.put(opts, :name, name)}, id: name)
      )

    # Allow the GenServer process to use the test's DB connection.
    Sandbox.allow(Repo, self(), pid)
    {pid, name}
  end

  test "a :sweep triggers cleanup of orphaned rooms older than max_idle" do
    {:ok, fresh_room} = Rooms.create_room(%{})
    {:ok, stale_room} = Rooms.create_room(%{})
    _ = backdate_room!(stale_room, 7200)

    # Use a far-future sweep_interval so the only sweep is the one we trigger.
    {pid, _name} = start_cleaner!(sweep_interval: :timer.hours(1), max_idle: :timer.hours(1))

    send(pid, :sweep)
    # Synchronize with the GenServer to ensure :sweep has been processed.
    _ = :sys.get_state(pid)

    assert Rooms.get_room(stale_room.id) == nil
    assert Rooms.get_room(fresh_room.id).id == fresh_room.id
  end
end
