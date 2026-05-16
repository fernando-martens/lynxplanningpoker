defmodule LynxplanningpokerWeb.RoomLive.ShowTest do
  use LynxplanningpokerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users

  defp setup_room_with_user(name \\ "Alice") do
    {:ok, room} = Rooms.create_room(%{is_active: true})
    {:ok, user} = Users.create_user(%{room_id: room.id, name: name})
    {room, user}
  end

  defp logged_in_conn(conn, user_id) do
    Plug.Test.init_test_session(conn, %{"current_user_id" => user_id})
  end

  describe "mount/3" do
    test "renders the room scene when session has a user belonging to the room", %{conn: conn} do
      {room, user} = setup_room_with_user("Alice")
      conn = logged_in_conn(conn, user.id)

      {:ok, _view, html} = live(conn, ~p"/rooms/#{room.id}")
      assert html =~ "room-scene"
      assert html =~ "Alice"
    end

    test "redirects to invite page when session has no current_user_id", %{conn: conn} do
      {:ok, room} = Rooms.create_room(%{is_active: true})

      assert {:error, {:live_redirect, %{to: target}}} = live(conn, ~p"/rooms/#{room.id}")
      assert target == ~p"/rooms/invite/#{room.id}"
    end

    test "redirects to invite page when session user does not belong to this room", %{conn: conn} do
      {_room1, user} = setup_room_with_user("Stranger")
      {:ok, other_room} = Rooms.create_room(%{is_active: true})

      conn = logged_in_conn(conn, user.id)

      assert {:error, {:live_redirect, %{to: target}}} =
               live(conn, ~p"/rooms/#{other_room.id}")

      assert target == ~p"/rooms/invite/#{other_room.id}"
    end

    test "raises when room does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/rooms/#{Ecto.UUID.generate()}")
      end
    end
  end

  describe "vote event" do
    test "clicking a numeric card sets the user's vote and marks the card as selected", %{
      conn: conn
    } do
      {room, user} = setup_room_with_user()
      conn = logged_in_conn(conn, user.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-value='5']") |> render_click()
      assert render(view) =~ "room-card--selected"

      assert Users.get_user!(user.id).vote == 5
    end

    test "clicking a non-numeric card (e.g. '?') stores nil and does not mark as selected", %{
      conn: conn
    } do
      {room, user} = setup_room_with_user()
      {:ok, _voted} = Users.update_user(user, %{vote: 3})
      conn = logged_in_conn(conn, user.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-value='?']") |> render_click()

      assert Users.get_user!(user.id).vote == nil
    end

    test "shows the paw icon on the avatar of users who voted but votes stay hidden", %{
      conn: conn
    } do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, _bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-value='8']") |> render_click()
      html = render(view)

      assert html =~ "room-user-avatar--voted"
      refute html =~ "room-user-vote-num"
    end
  end

  describe "reveal event" do
    test "reveals all numeric votes after click", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: 5})
      {:ok, _} = Users.update_user(bob, %{vote: 8})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      html = view |> element("button", "Reveal") |> render_click()
      assert html =~ "room-user-vote-num"
      assert html =~ ">5<"
      assert html =~ ">8<"
      assert html =~ "Recomeçar"
    end
  end

  describe "reset event" do
    test "clears every user's vote and hides the values again", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: 5})
      {:ok, _} = Users.update_user(bob, %{vote: 8})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button", "Reveal") |> render_click()
      html = view |> element("button", "Recomeçar") |> render_click()

      assert Users.get_user!(alice.id).vote == nil
      assert Users.get_user!(bob.id).vote == nil
      assert html =~ "Reveal"
      refute html =~ "room-user-vote-num"
    end
  end

  describe "PubSub updates" do
    test "updates the participant list when another user joins the room", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      conn = logged_in_conn(conn, alice.id)
      {:ok, view, html} = live(conn, ~p"/rooms/#{room.id}")
      refute html =~ "Bob"

      {:ok, _bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      assert render(view) =~ "Bob"
    end

    test "updates avatar state when another user in the room votes", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      {:ok, _} = Users.update_user(bob, %{vote: 13})
      assert render(view) =~ "room-user-avatar--voted"
    end
  end
end
