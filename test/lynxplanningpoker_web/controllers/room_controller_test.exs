defmodule LynxplanningpokerWeb.RoomControllerTest do
  use LynxplanningpokerWeb.ConnCase, async: true

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users

  describe "GET /rooms/new" do
    test "renders the create-room form", %{conn: conn} do
      conn = get(conn, ~p"/rooms/new")
      response = html_response(conn, 200)
      assert response =~ "Who are you?"
      assert response =~ ~s(name="room[name]")
    end
  end

  describe "POST /rooms" do
    test "creates a room and a host user, sets session and redirects to the room", %{conn: conn} do
      conn =
        post(conn, ~p"/rooms", %{"room" => %{"name" => "Alice", "is_active" => "true"}})

      assert %{id: room_id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/rooms/#{room_id}"

      assert Rooms.get_room!(room_id)
      [user] = Users.list_users_by_room(room_id)
      assert user.name == "Alice"
      assert get_session(conn, :current_user_id) == user.id
    end

    test "re-renders form when room params are invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/rooms", %{
          "room" => %{"name" => "Alice", "is_active" => "not-a-boolean"}
        })

      assert html_response(conn, 200) =~ "Who are you?"
      assert Rooms.list_rooms() == []
    end
  end

  describe "GET /rooms/invite/:id" do
    test "renders the invite page for an existing room", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      conn = get(conn, ~p"/rooms/invite/#{room.id}")
      response = html_response(conn, 200)
      assert response =~ "invited"
      assert response =~ "Join the room"
    end

    test "redirects to home with a flash when the room does not exist", %{conn: conn} do
      conn = get(conn, ~p"/rooms/invite/#{Ecto.UUID.generate()}")
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "does not exist"
    end
  end

  describe "POST /rooms/invite/:id" do
    test "creates user, sets session and redirects to the room", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{is_active: true})

      conn = post(conn, ~p"/rooms/invite/#{room.id}", %{"name" => "Bob"})
      assert redirected_to(conn) == ~p"/rooms/#{room}"

      [user] = Users.list_users_by_room(room.id)
      assert user.name == "Bob"
      assert get_session(conn, :current_user_id) == user.id
    end

    test "re-renders invite page when name is blank", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      conn = post(conn, ~p"/rooms/invite/#{room.id}", %{"name" => ""})
      assert html_response(conn, 200) =~ "Join the room"
      assert Users.list_users_by_room(room.id) == []
    end
  end

  describe "cleanup of previous session when entering a new room" do
    test "POST /rooms deletes the user from the previous room when not host", %{conn: conn} do
      {:ok, old_room} = Rooms.create_room(%{is_active: true})
      {:ok, old_user} = Users.create_user(%{room_id: old_room.id, name: "Alice"})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_user.id})
      |> post(~p"/rooms", %{"room" => %{"name" => "Alice", "is_active" => "true"}})

      # Previous room still exists, but the previous user record is gone
      assert Rooms.get_room!(old_room.id)
      assert Users.list_users_by_room(old_room.id) == []
    end

    test "POST /rooms deletes the previous room entirely when user was host", %{conn: conn} do
      {:ok, old_room} = Rooms.create_room(%{is_active: true})

      {:ok, old_host} =
        Users.create_user(%{room_id: old_room.id, name: "Alice", is_host: true})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_host.id})
      |> post(~p"/rooms", %{"room" => %{"name" => "Alice", "is_active" => "true"}})

      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(old_room.id) end
    end

    test "POST /rooms/invite/:id deletes the user from the previous room when not host", %{
      conn: conn
    } do
      {:ok, old_room} = Rooms.create_room(%{is_active: true})
      {:ok, old_user} = Users.create_user(%{room_id: old_room.id, name: "Alice"})
      {:ok, new_room} = Rooms.create_room(%{is_active: true})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_user.id})
      |> post(~p"/rooms/invite/#{new_room.id}", %{"name" => "Alice"})

      assert Rooms.get_room!(old_room.id)
      assert Users.list_users_by_room(old_room.id) == []
      assert [_alice_in_new_room] = Users.list_users_by_room(new_room.id)
    end

    test "POST /rooms/invite/:id deletes the previous room when user was host", %{conn: conn} do
      {:ok, old_room} = Rooms.create_room(%{is_active: true})

      {:ok, old_host} =
        Users.create_user(%{room_id: old_room.id, name: "Alice", is_host: true})

      {:ok, new_room} = Rooms.create_room(%{is_active: true})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_host.id})
      |> post(~p"/rooms/invite/#{new_room.id}", %{"name" => "Alice"})

      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(old_room.id) end
      assert [_alice_in_new_room] = Users.list_users_by_room(new_room.id)
    end

    test "GET /rooms/invite/:id redirects straight to the room when user is already a member",
         %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      {:ok, host} = Users.create_user(%{room_id: room.id, name: "Alice", is_host: true})

      conn =
        conn
        |> Plug.Test.init_test_session(%{current_user_id: host.id})
        |> get(~p"/rooms/invite/#{room.id}")

      assert redirected_to(conn) == ~p"/rooms/#{room}"
      # No form was rendered, no extra user was created
      users = Users.list_users_by_room(room.id)
      assert length(users) == 1
      assert hd(users).id == host.id
    end
  end

  describe "GET /rooms/leave" do
    test "deletes the user, clears the session and redirects home", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{is_active: true})
      {:ok, user} = Users.create_user(%{room_id: room.id, name: "Alice"})

      conn =
        conn
        |> Plug.Test.init_test_session(%{current_user_id: user.id})
        |> get(~p"/rooms/leave")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_user_id) == nil
      assert Users.list_users_by_room(room.id) == []
    end

    test "clears the session and redirects home when user no longer exists", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{current_user_id: Ecto.UUID.generate()})
        |> get(~p"/rooms/leave")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_user_id) == nil
    end

    test "redirects home when there is no session", %{conn: conn} do
      conn = get(conn, ~p"/rooms/leave")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
