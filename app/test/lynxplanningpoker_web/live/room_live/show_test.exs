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

    test "redirects to home with a flash when the room does not exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/rooms/#{Ecto.UUID.generate()}")

      assert flash["error"] =~ "does not exist"
    end
  end

  describe "vote event" do
    test "clicking a numeric card sets the user's vote and marks the card as selected", %{
      conn: conn
    } do
      {room, user} = setup_room_with_user()
      conn = logged_in_conn(conn, user.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='5']") |> render_click()
      assert render(view) =~ ~s(class="room-card room-card--selected")

      updated = Users.get_user!(user.id)
      assert updated.vote == "5"
      assert updated.vote_value == 5
    end

    test "clicking the already-selected card toggles the vote off", %{conn: conn} do
      {room, user} = setup_room_with_user()
      conn = logged_in_conn(conn, user.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='5']") |> render_click()
      assert Users.get_user!(user.id).vote == "5"

      view |> element("button[phx-value-card='5']") |> render_click()
      updated = Users.get_user!(user.id)
      assert updated.vote == nil
      assert updated.vote_value == nil
      refute render(view) =~ ~s(class="room-card room-card--selected")
    end

    test "clicking the '?' card stores it as a label with nil numeric value and marks it as selected",
         %{conn: conn} do
      {room, user} = setup_room_with_user()
      conn = logged_in_conn(conn, user.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='?']") |> render_click()

      updated = Users.get_user!(user.id)
      assert updated.vote == "?"
      assert updated.vote_value == nil
      assert render(view) =~ ~s(class="room-card room-card--selected")
    end

    test "clicking the '?' card again toggles the vote off", %{conn: conn} do
      {room, user} = setup_room_with_user()
      conn = logged_in_conn(conn, user.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='?']") |> render_click()
      assert Users.get_user!(user.id).vote == "?"

      view |> element("button[phx-value-card='?']") |> render_click()
      updated = Users.get_user!(user.id)
      assert updated.vote == nil
      assert updated.vote_value == nil
      refute render(view) =~ ~s(class="room-card room-card--selected")
    end

    test "the '?' vote does not count toward the numeric average after reveal", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: "?"})
      {:ok, _} = Users.update_user(bob, %{vote: "8"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      html = view |> element("button", "Reveal") |> render_click()
      assert html =~ "room-average-value"
      assert html =~ ">8.0<"
      assert html =~ ">?<"
    end

    test "hides the current user's own vote number before reveal (shows paw instead)", %{
      conn: conn
    } do
      {room, alice} = setup_room_with_user("Alice")
      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='8']") |> render_click()
      html = render(view)

      assert html =~ "room-user-avatar--voted"
      refute html =~ "room-user-vote-num"
    end

    test "reveals the current user's own vote number after reveal", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='8']") |> render_click()
      view |> element("button", "Reveal") |> render_click()
      html = render(view)

      assert html =~ "room-user-vote-num"
      assert html =~ ">8<"
    end

    test "hides other users' vote numbers when the room is not revealed", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(bob, %{vote: "13"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, html} = live(conn, ~p"/rooms/#{room.id}")

      assert html =~ "room-user-avatar--voted"
      refute html =~ "room-user-vote-num"

      # The hidden vote value must not reach the client at all — assert via
      # socket assigns that Bob's vote was scrubbed before being sent.
      assigns = :sys.get_state(view.pid).socket.assigns
      bob_seen = Enum.find(assigns.users, &(&1.id == bob.id))
      assert bob_seen.vote == nil
      assert bob_seen.vote_value == nil
      assert bob_seen.has_voted == true
    end
  end

  describe "reveal event" do
    test "reveals all numeric votes after click", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: "5"})
      {:ok, _} = Users.update_user(bob, %{vote: "8"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      html = view |> element("button", "Reveal") |> render_click()
      assert html =~ "room-user-vote-num"
      assert html =~ ">5<"
      assert html =~ ">8<"
      assert html =~ "room-average-value"
      assert html =~ ">6.5<"
    end

    test "shows '—' as average when no numeric votes are present", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      html = view |> element("button", "Reveal") |> render_click()
      assert html =~ "room-average-value"
      assert html =~ "—"
    end

    test "persists revealed state on the room and propagates via PubSub", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(bob, %{vote: "13"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button", "Reveal") |> render_click()

      assert Rooms.get_room!(room.id).revealed == true
      assert render(view) =~ ">13<"
    end
  end

  describe "reset event" do
    test "clears every user's vote, resets revealed and hides the values again", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(alice, %{vote: "5"})
      {:ok, _} = Users.update_user(bob, %{vote: "8"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button", "Reveal") |> render_click()
      view |> element("button", "Restart") |> render_click()
      html = render(view)

      alice_after = Users.get_user!(alice.id)
      bob_after = Users.get_user!(bob.id)
      assert alice_after.vote == nil
      assert alice_after.vote_value == nil
      assert bob_after.vote == nil
      assert bob_after.vote_value == nil
      assert Rooms.get_room!(room.id).revealed == false
      assert html =~ "Reveal"
      refute html =~ "room-user-vote-num"
    end

    test "clears the vote_changed_after_reveal flag", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")

      {:ok, _} = Users.update_user(alice, %{vote: "5", vote_changed_after_reveal: true})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button", "Reveal") |> render_click()
      view |> element("button", "Restart") |> render_click()

      assert Users.get_user!(alice.id).vote_changed_after_reveal == false
    end
  end

  describe "vote_changed_after_reveal" do
    test "voting before reveal does not set the flag", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button[phx-value-card='5']") |> render_click()

      assert Users.get_user!(alice.id).vote_changed_after_reveal == false
    end

    test "changing the vote after reveal sets the flag and shows the pencil badge", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, _} = Users.update_user(alice, %{vote: "5"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view |> element("button", "Reveal") |> render_click()
      view |> element("button[phx-value-card='8']") |> render_click()

      assert Users.get_user!(alice.id).vote_changed_after_reveal == true
      assert render(view) =~ "room-user-edit-badge"
    end
  end

  describe "end_planning / leave_room events" do
    test "host header shows 'End planning' button", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, host} = Users.update_user(alice, %{is_host: true})

      conn = logged_in_conn(conn, host.id)
      {:ok, _view, html} = live(conn, ~p"/rooms/#{room.id}")

      assert html =~ "End planning"
      refute html =~ "Leave"
    end

    test "non-host header shows 'Leave' button", %{conn: conn} do
      {room, _alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      conn = logged_in_conn(conn, bob.id)
      {:ok, _view, html} = live(conn, ~p"/rooms/#{room.id}")

      assert html =~ "Leave"
      refute html =~ "End planning"
    end

    test "host clicking 'End planning' deletes the room", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, host} = Users.update_user(alice, %{is_host: true})

      conn = logged_in_conn(conn, host.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      assert {:error, {:redirect, %{to: "/rooms/leave"}}} =
               view |> element("button", "End planning") |> render_click()

      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(room.id) end
    end

    test "non-host clicking 'Leave' redirects through leave endpoint", %{conn: conn} do
      {room, _alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      conn = logged_in_conn(conn, bob.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      assert {:error, {:redirect, %{to: "/rooms/leave"}}} =
               view |> element("button", "Leave") |> render_click()

      assert Rooms.get_room!(room.id)
    end

    test "presence leave of a non-host deletes only that user", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, _host} = Users.update_user(alice, %{is_host: true})
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      send(
        view.pid,
        %Phoenix.Socket.Broadcast{
          topic: Lynxplanningpoker.Presence.room_topic(room.id),
          event: "presence_diff",
          payload: %{joins: %{}, leaves: %{bob.id => %{metas: [%{}]}}}
        }
      )

      _ = render(view)

      assert Rooms.get_room!(room.id)
      assert_raise Ecto.NoResultsError, fn -> Users.get_user!(bob.id) end
    end

    test "presence leave of the host deletes the entire room", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, host} = Users.update_user(alice, %{is_host: true})
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      conn = logged_in_conn(conn, bob.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      send(
        view.pid,
        %Phoenix.Socket.Broadcast{
          topic: Lynxplanningpoker.Presence.room_topic(room.id),
          event: "presence_diff",
          payload: %{joins: %{}, leaves: %{host.id => %{metas: [%{}]}}}
        }
      )

      assert_redirect(view, "/rooms/leave")
      assert Rooms.get_room(room.id) == nil
    end

    test "all clients are redirected when the room is deleted", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, _host} = Users.update_user(alice, %{is_host: true})
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})

      conn = logged_in_conn(conn, bob.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      Rooms.delete_room(Rooms.get_room!(room.id))

      assert_redirect(view, "/rooms/leave")
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

      {:ok, _} = Users.update_user(bob, %{vote: "13"})
      assert render(view) =~ "room-user-avatar--voted"
    end

    test "reveals votes when another client triggers reveal on the same room", %{conn: conn} do
      {room, alice} = setup_room_with_user("Alice")
      {:ok, bob} = Users.create_user(%{room_id: room.id, name: "Bob"})
      {:ok, _} = Users.update_user(bob, %{vote: "21"})

      conn = logged_in_conn(conn, alice.id)
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      refute render(view) =~ "room-user-vote-num"

      {:ok, _} = Rooms.update_room(Rooms.get_room!(room.id), %{revealed: true})

      assert render(view) =~ "room-user-vote-num"
    end
  end
end
