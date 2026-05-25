defmodule Lynxplanningpoker.RoomsTest do
  use Lynxplanningpoker.DataCase, async: true

  alias Lynxplanningpoker.Analytics
  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Rooms.Room

  describe "create_room/1" do
    test "creates a room with valid attrs" do
      assert {:ok, %Room{} = room} = Rooms.create_room(%{})
      assert room.revealed == false
      assert is_binary(room.id)
    end

    test "defaults revealed to false when not provided" do
      assert {:ok, %Room{revealed: false}} = Rooms.create_room(%{})
    end

    test "accepts an explicit revealed value" do
      assert {:ok, %Room{revealed: true}} = Rooms.create_room(%{revealed: true})
    end

    test "returns error changeset when revealed is explicitly nil" do
      assert {:error, %Ecto.Changeset{} = changeset} = Rooms.create_room(%{revealed: nil})
      assert %{revealed: ["can't be blank"]} = errors_on(changeset)
    end

    test "records the room creation in analytics" do
      assert {:ok, room} = Rooms.create_room(%{})
      assert Analytics.total_rooms() == 1
      assert Analytics.average_room_duration_seconds() == nil
      assert room.id
    end
  end

  describe "get_room!/1" do
    test "returns the room with the given id" do
      {:ok, room} = Rooms.create_room(%{})
      assert Rooms.get_room!(room.id).id == room.id
    end

    test "raises when room does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Rooms.get_room!(Ecto.UUID.generate())
      end
    end

    test "raises Ecto.NoResultsError when id is not a valid UUID" do
      assert_raise Ecto.NoResultsError, fn ->
        Rooms.get_room!("not-a-uuid")
      end
    end
  end

  describe "get_room/1" do
    test "returns the room with the given id" do
      {:ok, room} = Rooms.create_room(%{})
      assert Rooms.get_room(room.id).id == room.id
    end

    test "returns nil when room does not exist" do
      assert Rooms.get_room(Ecto.UUID.generate()) == nil
    end

    test "returns nil when id is not a valid UUID" do
      assert Rooms.get_room("not-a-uuid") == nil
      assert Rooms.get_room("3c707c09-7970-415f-9f59-cdd0e1b4ff4") == nil
    end
  end

  describe "list_rooms/0" do
    test "lists all rooms" do
      {:ok, room1} = Rooms.create_room(%{})
      {:ok, room2} = Rooms.create_room(%{})
      ids = Rooms.list_rooms() |> Enum.map(& &1.id)
      assert room1.id in ids
      assert room2.id in ids
    end
  end

  describe "update_room/2" do
    test "toggles revealed flag" do
      {:ok, room} = Rooms.create_room(%{})
      assert {:ok, %Room{revealed: true}} = Rooms.update_room(room, %{revealed: true})
    end

    test "returns error when invalid" do
      {:ok, room} = Rooms.create_room(%{})
      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(room, %{revealed: nil})
    end

    test "broadcasts the updated room to subscribers" do
      {:ok, room} = Rooms.create_room(%{})
      :ok = Rooms.subscribe_to_room(room.id)

      {:ok, updated} = Rooms.update_room(room, %{revealed: true})

      assert_receive {:room_updated, %Room{} = broadcast_room}
      assert broadcast_room.id == updated.id
      assert broadcast_room.revealed == true
    end

    test "does not broadcast when the update fails" do
      {:ok, room} = Rooms.create_room(%{})
      :ok = Rooms.subscribe_to_room(room.id)

      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(room, %{revealed: nil})
      refute_receive {:room_updated, _}, 50
    end
  end

  describe "delete_room/1" do
    test "deletes a room" do
      {:ok, room} = Rooms.create_room(%{})
      assert {:ok, %Room{}} = Rooms.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(room.id) end
    end

    test "marks the session as ended in analytics" do
      {:ok, room} = Rooms.create_room(%{})
      assert {:ok, %Room{}} = Rooms.delete_room(room)
      assert is_float(Analytics.average_room_duration_seconds())
    end
  end

  describe "change_room/1" do
    test "returns a changeset" do
      {:ok, room} = Rooms.create_room(%{})
      assert %Ecto.Changeset{} = Rooms.change_room(room)
    end
  end

  describe "delete_orphaned_rooms/1" do
    alias Lynxplanningpoker.Repo
    alias Lynxplanningpoker.Users

    # Backdates a room's `updated_at` directly via the repo so we can simulate
    # a room that has been idle long enough to be swept.
    defp backdate_room!(room, seconds_ago) do
      then =
        DateTime.utc_now() |> DateTime.add(-seconds_ago, :second) |> DateTime.truncate(:second)

      Repo.update_all(from(r in Room, where: r.id == ^room.id), set: [updated_at: then])
      Repo.get!(Room, room.id)
    end

    test "deletes a room with no users older than the threshold" do
      {:ok, room} = Rooms.create_room(%{})
      _ = backdate_room!(room, 7200)

      assert Rooms.delete_orphaned_rooms(:timer.hours(1)) == 1
      assert Rooms.get_room(room.id) == nil
    end

    test "keeps rooms that have users, even when older than the threshold" do
      {:ok, room} = Rooms.create_room(%{})
      {:ok, _user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      _ = backdate_room!(room, 7200)

      assert Rooms.delete_orphaned_rooms(:timer.hours(1)) == 0
      assert Rooms.get_room(room.id).id == room.id
    end

    test "keeps orphaned rooms that are still within the grace period" do
      {:ok, room} = Rooms.create_room(%{})

      assert Rooms.delete_orphaned_rooms(:timer.hours(1)) == 0
      assert Rooms.get_room(room.id).id == room.id
    end

    test "broadcasts {:room_deleted, id} for each swept room" do
      {:ok, room} = Rooms.create_room(%{})
      _ = backdate_room!(room, 7200)
      :ok = Rooms.subscribe_to_room(room.id)

      assert Rooms.delete_orphaned_rooms(:timer.hours(1)) == 1
      assert_receive {:room_deleted, room_id}
      assert room_id == room.id
    end
  end
end
