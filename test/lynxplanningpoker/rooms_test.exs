defmodule Lynxplanningpoker.RoomsTest do
  use Lynxplanningpoker.DataCase, async: true

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Rooms.Room

  describe "create_room/1" do
    test "creates a room with valid attrs" do
      assert {:ok, %Room{} = room} = Rooms.create_room(%{is_active: true})
      assert room.is_active == true
      assert room.revealed == false
      assert is_binary(room.id)
    end

    test "defaults is_active and revealed to false when not provided" do
      assert {:ok, %Room{is_active: false, revealed: false}} = Rooms.create_room(%{})
    end

    test "accepts an explicit revealed value" do
      assert {:ok, %Room{revealed: true}} =
               Rooms.create_room(%{is_active: true, revealed: true})
    end

    test "returns error changeset when is_active is explicitly nil" do
      assert {:error, %Ecto.Changeset{} = changeset} = Rooms.create_room(%{is_active: nil})
      assert %{is_active: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when revealed is explicitly nil" do
      assert {:error, %Ecto.Changeset{} = changeset} = Rooms.create_room(%{revealed: nil})
      assert %{revealed: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when is_active is not a valid boolean string" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Rooms.create_room(%{"is_active" => "not-a-boolean"})

      assert %{is_active: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "get_room!/1" do
    test "returns the room with the given id" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      assert Rooms.get_room!(room.id).id == room.id
    end

    test "raises when room does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Rooms.get_room!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_rooms/0" do
    test "lists all rooms" do
      {:ok, room1} = Rooms.create_room(%{is_active: true})
      {:ok, room2} = Rooms.create_room(%{is_active: false})
      ids = Rooms.list_rooms() |> Enum.map(& &1.id)
      assert room1.id in ids
      assert room2.id in ids
    end
  end

  describe "update_room/2" do
    test "updates room attributes" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      assert {:ok, updated} = Rooms.update_room(room, %{is_active: false})
      assert updated.is_active == false
    end

    test "toggles revealed flag" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      assert {:ok, %Room{revealed: true}} = Rooms.update_room(room, %{revealed: true})
    end

    test "returns error when invalid" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(room, %{is_active: nil})
    end

    test "broadcasts the updated room to subscribers" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      :ok = Rooms.subscribe_to_room(room.id)

      {:ok, updated} = Rooms.update_room(room, %{revealed: true})

      assert_receive {:room_updated, %Room{} = broadcast_room}
      assert broadcast_room.id == updated.id
      assert broadcast_room.revealed == true
    end

    test "does not broadcast when the update fails" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      :ok = Rooms.subscribe_to_room(room.id)

      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(room, %{is_active: nil})
      refute_receive {:room_updated, _}, 50
    end
  end

  describe "delete_room/1" do
    test "deletes a room" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      assert {:ok, %Room{}} = Rooms.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(room.id) end
    end
  end

  describe "change_room/1" do
    test "returns a changeset" do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      assert %Ecto.Changeset{} = Rooms.change_room(room)
    end
  end
end
