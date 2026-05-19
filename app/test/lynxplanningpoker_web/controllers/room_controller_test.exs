defmodule LynxplanningpokerWeb.RoomControllerTest do
  # async: false because some tests mutate `:lynxplanningpoker, :turnstile`
  # via Application.put_env/3 to exercise the verification gate.
  use LynxplanningpokerWeb.ConnCase, async: false

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users

  # Helper: enable Turnstile for a single test with `secret_key: nil` so the
  # verifier returns {:error, :missing_secret} without doing any HTTP.
  defp enable_turnstile_without_secret(_context) do
    original = Application.get_env(:lynxplanningpoker, :turnstile)

    Application.put_env(:lynxplanningpoker, :turnstile,
      enabled: true,
      site_key: "test-site-key",
      secret_key: nil
    )

    on_exit(fn -> Application.put_env(:lynxplanningpoker, :turnstile, original) end)
    :ok
  end

  describe "GET /rooms/new" do
    test "renders the create-room form", %{conn: conn} do
      conn = get(conn, ~p"/rooms/new")
      response = html_response(conn, 200)
      assert response =~ "Who are you?"
      assert response =~ ~s(name="room[name]")
    end

    test "renders the Turnstile widget when enabled", %{conn: conn} do
      original = Application.get_env(:lynxplanningpoker, :turnstile)

      Application.put_env(:lynxplanningpoker, :turnstile,
        enabled: true,
        site_key: "1x00000000000000000000AA",
        secret_key: "secret"
      )

      on_exit(fn -> Application.put_env(:lynxplanningpoker, :turnstile, original) end)

      conn = get(conn, ~p"/rooms/new")
      response = html_response(conn, 200)
      assert response =~ "cf-turnstile"
      assert response =~ "1x00000000000000000000AA"
      assert response =~ "challenges.cloudflare.com/turnstile/v0/api.js"
    end

    test "omits the Turnstile widget when disabled", %{conn: conn} do
      conn = get(conn, ~p"/rooms/new")
      response = html_response(conn, 200)
      refute response =~ "cf-turnstile"
      refute response =~ "challenges.cloudflare.com"
    end
  end

  describe "POST /rooms" do
    test "creates a room and a host user, sets session and redirects to the room", %{conn: conn} do
      conn =
        post(conn, ~p"/rooms", %{"room" => %{"name" => "Alice"}})

      assert %{id: room_id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/rooms/#{room_id}"

      assert Rooms.get_room!(room_id)
      [user] = Users.list_users_by_room(room_id)
      assert user.name == "Alice"
      assert get_session(conn, :current_user_id) == user.id
    end
  end

  describe "POST /rooms with Turnstile enabled" do
    setup :enable_turnstile_without_secret

    test "blocks creation and re-renders the form when verification fails", %{conn: conn} do
      conn =
        post(conn, ~p"/rooms", %{
          "room" => %{"name" => "Alice"},
          "cf-turnstile-response" => "any-token"
        })

      response = html_response(conn, 200)
      assert response =~ "Who are you?"
      assert response =~ "human verification"
      assert Rooms.list_rooms() == []
      assert get_session(conn, :current_user_id) == nil
    end
  end

  describe "GET /rooms/invite/:id" do
    test "renders the invite page for an existing room", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{})
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
      {:ok, room} = Rooms.create_room(%{})

      conn = post(conn, ~p"/rooms/invite/#{room.id}", %{"name" => "Bob"})
      assert redirected_to(conn) == ~p"/rooms/#{room}"

      [user] = Users.list_users_by_room(room.id)
      assert user.name == "Bob"
      assert get_session(conn, :current_user_id) == user.id
    end

    test "re-renders invite page when name is blank", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{})
      conn = post(conn, ~p"/rooms/invite/#{room.id}", %{"name" => ""})
      assert html_response(conn, 200) =~ "Join the room"
      assert Users.list_users_by_room(room.id) == []
    end

    test "rejects the 16th player with a flash and does not create the user", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{})

      for i <- 1..Users.max_users_per_room() do
        {:ok, _} = Users.create_user(%{room_id: room.id, name: "Player #{i}"})
      end

      conn = post(conn, ~p"/rooms/invite/#{room.id}", %{"name" => "Latecomer"})

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "full"
      assert length(Users.list_users_by_room(room.id)) == Users.max_users_per_room()
    end
  end

  describe "room capacity on GET /rooms/invite/:id" do
    test "redirects home with a flash when the room is full", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{})

      for i <- 1..Users.max_users_per_room() do
        {:ok, _} = Users.create_user(%{room_id: room.id, name: "Player #{i}"})
      end

      conn = get(conn, ~p"/rooms/invite/#{room.id}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "full"
    end

    test "still lets an existing member through when the room is full", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{})

      [first | _] =
        for i <- 1..Users.max_users_per_room() do
          {:ok, user} = Users.create_user(%{room_id: room.id, name: "Player #{i}"})
          user
        end

      conn =
        conn
        |> Plug.Test.init_test_session(%{current_user_id: first.id})
        |> get(~p"/rooms/invite/#{room.id}")

      assert redirected_to(conn) == ~p"/rooms/#{room}"
    end
  end

  describe "cleanup of previous session when entering a new room" do
    test "POST /rooms deletes the user from the previous room when not host", %{conn: conn} do
      {:ok, old_room} = Rooms.create_room(%{})
      {:ok, old_user} = Users.create_user(%{room_id: old_room.id, name: "Alice"})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_user.id})
      |> post(~p"/rooms", %{"room" => %{"name" => "Alice"}})

      # Previous room still exists, but the previous user record is gone
      assert Rooms.get_room!(old_room.id)
      assert Users.list_users_by_room(old_room.id) == []
    end

    test "POST /rooms deletes the previous room entirely when user was host", %{conn: conn} do
      {:ok, old_room} = Rooms.create_room(%{})

      {:ok, old_host} =
        Users.create_user(%{room_id: old_room.id, name: "Alice", is_host: true})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_host.id})
      |> post(~p"/rooms", %{"room" => %{"name" => "Alice"}})

      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(old_room.id) end
    end

    test "POST /rooms/invite/:id deletes the user from the previous room when not host", %{
      conn: conn
    } do
      {:ok, old_room} = Rooms.create_room(%{})
      {:ok, old_user} = Users.create_user(%{room_id: old_room.id, name: "Alice"})
      {:ok, new_room} = Rooms.create_room(%{})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_user.id})
      |> post(~p"/rooms/invite/#{new_room.id}", %{"name" => "Alice"})

      assert Rooms.get_room!(old_room.id)
      assert Users.list_users_by_room(old_room.id) == []
      assert [_alice_in_new_room] = Users.list_users_by_room(new_room.id)
    end

    test "POST /rooms/invite/:id deletes the previous room when user was host", %{conn: conn} do
      {:ok, old_room} = Rooms.create_room(%{})

      {:ok, old_host} =
        Users.create_user(%{room_id: old_room.id, name: "Alice", is_host: true})

      {:ok, new_room} = Rooms.create_room(%{})

      conn
      |> Plug.Test.init_test_session(%{current_user_id: old_host.id})
      |> post(~p"/rooms/invite/#{new_room.id}", %{"name" => "Alice"})

      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(old_room.id) end
      assert [_alice_in_new_room] = Users.list_users_by_room(new_room.id)
    end

    test "GET /rooms/invite/:id redirects straight to the room when user is already a member",
         %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{})
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
      {:ok, room} = Rooms.create_room(%{})
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
