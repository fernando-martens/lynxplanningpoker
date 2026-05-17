defmodule LynxplanningpokerWeb.RoomLive.Show do
  use LynxplanningpokerWeb, :live_view

  alias Lynxplanningpoker.Decks
  alias Lynxplanningpoker.Presence
  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users

  @cards Decks.labels(Decks.default())

  @impl true
  def mount(%{"id" => id}, session, socket) do
    case Rooms.get_room(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This room does not exist or has already ended."))
         |> push_navigate(to: ~p"/")}

      room ->
        current_user_id = session["current_user_id"]
        users = Users.list_users_by_room(id, current_user_id, room.revealed)
        current_user = current_user_id && Enum.find(users, &(&1.id == current_user_id))

        if current_user do
          if connected?(socket) do
            Users.subscribe_to_room(id)
            Rooms.subscribe_to_room(id)

            presence_topic = Presence.room_topic(id)
            Phoenix.PubSub.subscribe(Lynxplanningpoker.PubSub, presence_topic)
            Presence.track(self(), presence_topic, current_user.id, %{})
          end

          show_initial_invite =
            connected?(socket) and current_user.is_host and length(users) == 1

          socket =
            socket
            |> assign(:room, room)
            |> assign(:users, users)
            |> assign(:current_user_id, current_user.id)
            |> assign(:current_user, current_user)
            |> assign(:cards, @cards)
            |> assign(:show_initial_invite, show_initial_invite)

          {:ok, socket}
        else
          {:ok, push_navigate(socket, to: ~p"/rooms/invite/#{id}")}
        end
    end
  end

  @impl true
  def handle_event("vote", %{"card" => label}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket}

      current_user ->
        new_vote = if current_user.vote == label, do: nil, else: label
        base_attrs = %{vote: new_vote}

        attrs =
          if socket.assigns.room.revealed do
            Map.put(base_attrs, :vote_changed_after_reveal, true)
          else
            base_attrs
          end

        case Users.update_user(current_user, attrs) do
          {:ok, updated_user} ->
            updated_user = %{updated_user | has_voted: not is_nil(updated_user.vote)}

            users =
              Enum.map(socket.assigns.users, fn user ->
                if user.id == updated_user.id, do: updated_user, else: user
              end)

            {:noreply, socket |> assign(:current_user, updated_user) |> assign(:users, users)}

          {:error, _changeset} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not register your vote. Please try again.")
             )}
        end
    end
  end

  @impl true
  def handle_event("reveal", _params, socket) do
    case Rooms.update_room(socket.assigns.room, %{revealed: true}) do
      {:ok, room} ->
        users =
          Users.list_users_by_room(room.id, socket.assigns.current_user_id, room.revealed)

        current_user = Enum.find(users, &(&1.id == socket.assigns.current_user_id))

        {:noreply,
         socket
         |> assign(:room, room)
         |> assign(:users, users)
         |> assign(:current_user, current_user)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset", _params, socket) do
    Enum.each(socket.assigns.users, fn user ->
      Users.update_user(user, %{vote: nil, vote_changed_after_reveal: false})
    end)

    case Rooms.update_room(socket.assigns.room, %{revealed: false}) do
      {:ok, room} ->
        users =
          Users.list_users_by_room(room.id, socket.assigns.current_user_id, room.revealed)

        current_user = Enum.find(users, &(&1.id == socket.assigns.current_user_id))

        {:noreply,
         socket
         |> assign(:room, room)
         |> assign(:users, users)
         |> assign(:current_user, current_user)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("end_planning", _params, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.is_host do
      Rooms.delete_room(socket.assigns.room)
      {:noreply, redirect(socket, to: ~p"/rooms/leave")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("leave_room", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/rooms/leave")}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff", payload: %{leaves: leaves}},
        socket
      ) do
    if map_size(leaves) > 0 do
      room_id = socket.assigns.room.id
      still_present = Presence.list(Presence.room_topic(room_id))

      for {user_id, _meta} <- leaves, not Map.has_key?(still_present, user_id) do
        try do
          user = Users.get_user!(user_id)

          if user.is_host do
            case Rooms.get_room(user.room_id) do
              nil -> :ok
              room -> Rooms.delete_room(room)
            end
          else
            Users.delete_user(user)
          end
        rescue
          Ecto.NoResultsError -> :ok
        end
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_deleted, room_id}, socket) do
    if socket.assigns.room.id == room_id do
      {:noreply,
       socket
       |> put_flash(:info, gettext("The room was ended by the host."))
       |> redirect(to: ~p"/rooms/leave")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:users_updated, room_id}, socket) do
    if socket.assigns.room.id == room_id do
      users =
        Users.list_users_by_room(
          room_id,
          socket.assigns.current_user_id,
          socket.assigns.room.revealed
        )

      current_user = Enum.find(users, &(&1.id == socket.assigns.current_user_id))
      {:noreply, socket |> assign(:users, users) |> assign(:current_user, current_user)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:room_updated, %Lynxplanningpoker.Rooms.Room{} = room}, socket) do
    if socket.assigns.room.id == room.id do
      users =
        Users.list_users_by_room(room.id, socket.assigns.current_user_id, room.revealed)

      current_user = Enum.find(users, &(&1.id == socket.assigns.current_user_id))

      {:noreply,
       socket
       |> assign(:room, room)
       |> assign(:users, users)
       |> assign(:current_user, current_user)}
    else
      {:noreply, socket}
    end
  end

  defp user_positions([]), do: []

  # Ellipse opens up as more users join: tight ring when few people are
  # present, full table when the room is crowded.
  @min_radius_x 28
  @max_radius_x 42
  @min_radius_y 32
  @max_radius_y 44
  @radius_ramp_start 2
  @radius_ramp_end 12

  defp user_positions(users) do
    total = length(users)

    t =
      ((total - @radius_ramp_start) / (@radius_ramp_end - @radius_ramp_start))
      |> max(0.0)
      |> min(1.0)

    rx = @min_radius_x + (@max_radius_x - @min_radius_x) * t
    ry = @min_radius_y + (@max_radius_y - @min_radius_y) * t

    Enum.with_index(users)
    |> Enum.map(fn {user, i} ->
      angle = -:math.pi() / 2 + 2 * :math.pi() / total * i
      x = 50 + rx * :math.cos(angle)
      y = 50 + ry * :math.sin(angle)
      {user, Float.round(x, 2), Float.round(y, 2)}
    end)
  end

  defp card_selected?(nil, _card), do: false
  defp card_selected?(%{vote: v}, card), do: v == card

  defp vote_average(users) do
    numeric_votes = for %{vote_value: v} <- users, is_integer(v), do: v

    case numeric_votes do
      [] ->
        "—"

      votes ->
        avg = Enum.sum(votes) / length(votes)
        :erlang.float_to_binary(avg, decimals: 1)
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :user_positions, user_positions(assigns.users))

    ~H"""
    <Layouts.room_header is_host={@current_user && @current_user.is_host} />
    <.modal id="invite-modal" title={gettext("Invitation link")}>
      <div class="flex flex-col sm:flex-row gap-2 items-stretch">
        <input
          id="invite-url"
          type="text"
          readonly
          value={url(~p"/rooms/invite/#{@room.id}")}
          data-copy-feedback="copy-feedback"
          class="flex-1 input input-bordered rounded-xl border border-base-300 bg-base-100 px-4 py-3 text-sm"
          onclick="this.select()"
        />
        <div class="relative">
          <button
            type="button"
            class="btn rounded-xl bg-base-200 hover:bg-base-300 px-4 py-3 inline-flex items-center justify-center gap-2 whitespace-nowrap w-full"
            phx-click={JS.dispatch("phx:copy", to: "#invite-url")}
          >
            <.icon name="hero-document-duplicate" class="size-4" /> {gettext("Copy")}
          </button>
          <div
            id="copy-feedback"
            style="display: none"
            class="absolute -top-9 left-1/2 -translate-x-1/2 z-10 px-2.5 py-1 rounded-md bg-base-content text-base-100 text-xs font-medium whitespace-nowrap shadow-lg items-center gap-1"
            role="status"
          >
            <.icon name="hero-check-circle" class="size-3.5" /> {gettext("Link copied!")}
            <span class="absolute top-full left-1/2 -translate-x-1/2 -mt-px border-4 border-transparent border-t-base-content">
            </span>
          </div>
        </div>
      </div>

      <p class="mt-3 text-xs text-base-content/60">
        {gettext("Anyone with this link can join the room")}
      </p>
    </.modal>

    <div
      :if={@show_initial_invite}
      id="initial-invite-trigger"
      class="hidden"
      phx-mounted={show_modal("invite-modal")}
    />
    <div class="room-scene">
      <div class="room-loading-overlay" aria-hidden="true">
        <div class="room-loading-spinner"></div>
      </div>
      <%!-- Game area --%>
      <div class="room-game-area">
        <div class="room-table">
          <%!-- Users positioned around campfire --%>
          <%= for {user, x, y} <- @user_positions do %>
            <div class="room-user" style={"left:#{x}%;top:#{y}%"}>
              <div class={"room-user-avatar #{if user.has_voted, do: "room-user-avatar--voted", else: ""}"}>
                <%= cond do %>
                  <% @room.revealed and user.vote != nil -> %>
                    <span class="room-user-vote-num">{user.vote}</span>
                  <% user.has_voted -> %>
                    <.paw_icon />
                  <% true -> %>
                    <span class="room-user-initials">{initials(user.name)}</span>
                <% end %>

                <%= if @room.revealed and user.vote_changed_after_reveal do %>
                  <span class="room-user-edit-badge" title={gettext("Vote changed after reveal")}>
                    <.pencil_icon />
                  </span>
                <% end %>
              </div>
              <span class="room-user-name">{user.name}</span>
            </div>
          <% end %>
          <%!-- Campfire at center --%>
          <div class="room-campfire-wrap">
            <%= if @room.revealed do %>
              <div id="campfire">
                <div id="wood"><span></span></div>

                <div id="fire"></div>
              </div>

              <div class="room-average" aria-label={gettext("Vote average")}>
                <span class="room-average-label">{gettext("Average")}</span>
                <span class="room-average-value">{vote_average(@users)}</span>
              </div>
            <% else %>
              <button
                type="button"
                phx-click="reveal"
                class="room-campfire-btn"
                aria-label={gettext("Reveal")}
              >
                <div id="campfire">
                  <div id="wood"><span></span></div>

                  <div id="fire"></div>
                </div>
                <span class="sr-only">{gettext("Reveal")}</span>
              </button>
              <p class="room-campfire-hint">{gettext("Click the fire to reveal")}</p>
            <% end %>
          </div>
        </div>
      </div>
      <%!-- Cards bar at bottom --%>
      <div class="room-cards-bar">
        <div class="room-cards-scroll">
          <div class="room-cards-inner">
            <%= for card <- @cards do %>
              <button
                phx-click="vote"
                phx-value-card={card}
                class={"room-card #{if card_selected?(@current_user, card), do: "room-card--selected", else: ""}"}
              >
                <span class="room-card-spinner" aria-hidden="true"></span>
                <span class="room-card-paw room-card-paw--tl"><.paw_icon /></span>
                <span class="room-card-paw room-card-paw--br"><.paw_icon /></span>
                <span class="room-card-value">{card}</span>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp paw_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width="1em"
      height="1em"
      fill="currentColor"
    >
      <circle cx="6" cy="7" r="2" /> <circle cx="12" cy="5" r="2" /> <circle cx="18" cy="7" r="2" />
      <circle cx="4" cy="12" r="1.5" /> <path d="M12 10c-3.5 0-6 2-6 5s2 5 6 5 6-2 6-5-2.5-5-6-5z" />
    </svg>
    """
  end

  defp pencil_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width="1em"
      height="1em"
      fill="currentColor"
    >
      <path d="M14.06 9.02l.92.92L5.92 19H5v-.92l9.06-9.06m3.6-6.02c-.25 0-.51.1-.7.29l-1.83 1.83 3.75 3.75 1.83-1.83a.996.996 0 000-1.41l-2.34-2.34a.97.97 0 00-.71-.29zM14.06 6.19L3 17.25V21h3.75L17.81 9.94l-3.75-3.75z" />
    </svg>
    """
  end
end
