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

    test "raises when room does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/rooms/invite/#{Ecto.UUID.generate()}")
      end
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
end
