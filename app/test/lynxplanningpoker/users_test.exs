defmodule Lynxplanningpoker.UsersTest do
  use Lynxplanningpoker.DataCase, async: false

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users
  alias Lynxplanningpoker.Users.User

  defp create_room!(attrs \\ %{is_active: true}) do
    {:ok, room} = Rooms.create_room(attrs)
    room
  end

  describe "create_user/1" do
    test "creates a user with valid attrs and broadcasts" do
      room = create_room!()
      Users.subscribe_to_room(room.id)

      assert {:ok, %User{} = user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      assert user.name == "Alice"
      assert user.room_id == room.id
      assert user.vote == nil

      assert_receive {:users_updated, room_id}
      assert room_id == room.id
    end

    test "returns error when name is missing" do
      room = create_room!()
      assert {:error, %Ecto.Changeset{} = changeset} = Users.create_user(%{room_id: room.id})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when room_id is missing" do
      assert {:error, %Ecto.Changeset{} = changeset} = Users.create_user(%{name: "Bob"})
      assert %{room_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when name is longer than 20 characters" do
      room = create_room!()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.create_user(%{room_id: room.id, name: String.duplicate("a", 21)})

      assert %{name: ["should be at most 20 character(s)"]} = errors_on(changeset)
    end

    test "accepts a name with exactly 20 characters" do
      room = create_room!()

      assert {:ok, %User{name: name}} =
               Users.create_user(%{room_id: room.id, name: String.duplicate("a", 20)})

      assert String.length(name) == 20
    end

    test "returns error when room_id does not exist" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.create_user(%{room_id: Ecto.UUID.generate(), name: "Bob"})

      assert %{room_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "get_user!/1" do
    test "returns the user with the given id" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      assert Users.get_user!(user.id).id == user.id
    end

    test "raises when user does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Users.get_user!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_users_by_room/1" do
    test "returns only users from the given room, ordered by name asc" do
      room1 = create_room!()
      room2 = create_room!()

      {:ok, _u1} = Users.create_user(%{room_id: room1.id, name: "Charlie"})
      {:ok, _u2} = Users.create_user(%{room_id: room1.id, name: "Alice"})
      {:ok, _u3} = Users.create_user(%{room_id: room1.id, name: "Bob"})
      {:ok, _u4} = Users.create_user(%{room_id: room2.id, name: "Zed"})

      names = Users.list_users_by_room(room1.id) |> Enum.map(& &1.name)
      assert names == ["Alice", "Bob", "Charlie"]
    end

    test "returns empty list when no users in the room" do
      room = create_room!()
      assert Users.list_users_by_room(room.id) == []
    end
  end

  describe "list_users_by_room/3" do
    test "hides other users' vote values when the room is not revealed" do
      room = create_room!()
      {:ok, alice} = Users.create_user(%{room_id: room.id, name: "Alice"})
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: "5"})
      {:ok, _} = Users.update_user(bob, %{vote: "13"})

      [alice_seen, bob_seen] = Users.list_users_by_room(room.id, alice.id, false)

      assert alice_seen.id == alice.id
      assert alice_seen.vote == "5"
      assert alice_seen.vote_value == 5
      assert alice_seen.has_voted == true

      assert bob_seen.id == bob.id
      assert bob_seen.vote == nil
      assert bob_seen.vote_value == nil
      assert bob_seen.has_voted == true
    end

    test "exposes every vote value when the room is revealed" do
      room = create_room!()
      {:ok, alice} = Users.create_user(%{room_id: room.id, name: "Alice"})
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: "5"})
      {:ok, _} = Users.update_user(bob, %{vote: "13"})

      [alice_seen, bob_seen] = Users.list_users_by_room(room.id, alice.id, true)

      assert alice_seen.vote == "5"
      assert alice_seen.vote_value == 5
      assert alice_seen.has_voted == true
      assert bob_seen.vote == "13"
      assert bob_seen.vote_value == 13
      assert bob_seen.has_voted == true
    end

    test "marks has_voted as false for users without a vote" do
      room = create_room!()
      {:ok, alice} = Users.create_user(%{room_id: room.id, name: "Alice"})
      {:ok, _bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      [alice_seen, bob_seen] = Users.list_users_by_room(room.id, alice.id, false)

      assert alice_seen.vote == nil
      assert alice_seen.has_voted == false
      assert bob_seen.vote == nil
      assert bob_seen.has_voted == false
    end

    test "hides every vote value when viewer_user_id is nil and room not revealed" do
      room = create_room!()
      {:ok, alice} = Users.create_user(%{room_id: room.id, name: "Alice"})
      {:ok, _} = Users.update_user(alice, %{vote: "5"})

      [alice_seen] = Users.list_users_by_room(room.id, nil, false)
      assert alice_seen.vote == nil
      assert alice_seen.vote_value == nil
      assert alice_seen.has_voted == true
    end

    test "returns empty list when no users in the room" do
      room = create_room!()
      assert Users.list_users_by_room(room.id, nil, false) == []
    end
  end

  describe "room capacity" do
    test "max_users_per_room/0 returns 15" do
      assert Users.max_users_per_room() == 15
    end

    test "count_users_by_room/1 returns the number of users in the room" do
      room = create_room!()
      other = create_room!()

      {:ok, _} = Users.create_user(%{room_id: room.id, name: "A"})
      {:ok, _} = Users.create_user(%{room_id: room.id, name: "B"})
      {:ok, _} = Users.create_user(%{room_id: other.id, name: "C"})

      assert Users.count_users_by_room(room.id) == 2
    end

    test "room_full?/1 is false below the limit and true at the limit" do
      room = create_room!()
      refute Users.room_full?(room.id)

      for i <- 1..Users.max_users_per_room() do
        {:ok, _} = Users.create_user(%{room_id: room.id, name: "Player #{i}"})
      end

      assert Users.room_full?(room.id)
    end
  end

  describe "list_users/0" do
    test "lists all users across rooms" do
      room1 = create_room!()
      room2 = create_room!()
      {:ok, u1} = Users.create_user(%{room_id: room1.id, name: "A"})
      {:ok, u2} = Users.create_user(%{room_id: room2.id, name: "B"})

      ids = Users.list_users() |> Enum.map(& &1.id)
      assert u1.id in ids
      assert u2.id in ids
    end
  end

  describe "update_user/2" do
    test "updates the vote and derives vote_value, broadcasting" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      Users.subscribe_to_room(room.id)

      assert {:ok, %User{vote: "5", vote_value: 5}} = Users.update_user(user, %{vote: "5"})

      assert_receive {:users_updated, room_id}
      assert room_id == room.id
    end

    test "stores a non-numeric vote with a nil vote_value" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})

      assert {:ok, %User{vote: "?", vote_value: nil}} = Users.update_user(user, %{vote: "?"})
    end

    test "can set vote back to nil" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      {:ok, voted} = Users.update_user(user, %{vote: "8"})

      assert {:ok, %User{vote: nil, vote_value: nil}} = Users.update_user(voted, %{vote: nil})
    end

    test "returns error when invalid" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      assert {:error, %Ecto.Changeset{}} = Users.update_user(user, %{name: nil})
    end
  end

  describe "delete_user/1" do
    test "deletes the user and broadcasts the room update" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      Users.subscribe_to_room(room.id)

      assert {:ok, %User{}} = Users.delete_user(user)
      assert_receive {:users_updated, room_id}
      assert room_id == room.id
      assert_raise Ecto.NoResultsError, fn -> Users.get_user!(user.id) end
    end
  end

  describe "change_user/1" do
    test "returns a changeset" do
      room = create_room!()
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      assert %Ecto.Changeset{} = Users.change_user(user)
    end
  end

  describe "subscribe_to_room/1" do
    test "subscribes the current process to broadcasts for that room" do
      room = create_room!()
      assert :ok = Users.subscribe_to_room(room.id)
      {:ok, _user} = Users.create_user(%{room_id: room.id, name: "Alice"})
      assert_receive {:users_updated, room_id}
      assert room_id == room.id
    end

    test "does not receive broadcasts from other rooms" do
      room1 = create_room!()
      room2 = create_room!()
      Users.subscribe_to_room(room1.id)
      {:ok, _user} = Users.create_user(%{room_id: room2.id, name: "Other"})
      refute_receive {:users_updated, _}, 100
    end
  end
end
