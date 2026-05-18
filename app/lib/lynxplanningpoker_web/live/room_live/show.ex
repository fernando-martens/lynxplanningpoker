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
              <div class={[
                "room-user-avatar",
                user.has_voted && "room-user-avatar--voted",
                !user.has_voted && !@room.revealed && "room-user-avatar--empty"
              ]}>
                <%= cond do %>
                  <% @room.revealed and user.vote != nil -> %>
                    <span class="room-user-vote-num">{user.vote}</span>
                  <% @room.revealed -> %>
                    <span class="room-user-vote-num">?</span>
                  <% user.has_voted -> %>
                    <.paw_icon />
                  <% true -> %>
                    <.tent_icon />
                    <span class="room-user-zzz room-user-zzz--1" aria-hidden="true">Z</span>
                    <span class="room-user-zzz room-user-zzz--2" aria-hidden="true">Z</span>
                    <span class="room-user-zzz room-user-zzz--3" aria-hidden="true">Z</span>
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
              <div id="campfire" class="campfire--settled">
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

  defp tent_icon(assigns) do
    ~H"""
    <svg
      class="room-user-tent"
      viewBox="0 0 60 38"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M38.6522 4.36674C30.7337 6.45559 22.1105 4.55223 18.6087 3.68188L36.607 34.3726H56.2488L38.6522 4.36674Z"
        fill="var(--tent-light)"
      />
      <path
        d="M18.6087 3.68188L0.652174 34.3726H6.25841C14.9565 27.9941 18.6087 12.971 18.6087 13.3128C18.6087 13.6547 22.099 27.8934 30.959 34.3726H36.607L18.6087 3.68188Z"
        fill="var(--tent-mid)"
      />
      <path
        d="M30.959 34.3726C22.099 27.8934 18.6087 13.6547 18.6087 13.3128C18.6087 12.971 14.9565 27.9941 6.25841 34.3726H30.959Z"
        fill="var(--tent-dark)"
      />
      <path
        d="M55.5966 36.3843V35.0146H37.2592V36.3843C37.2592 36.7389 36.9672 37.0264 36.607 37.0264C36.2468 37.0264 35.9548 36.7389 35.9548 36.3843V35.0146H1.30435V36.3843C1.30435 36.7389 1.01236 37.0264 0.652174 37.0264C0.291988 37.0264 0 36.7389 0 36.3843V30.3917C0 30.0371 0.291988 29.7497 0.652174 29.7497C1.01236 29.7497 1.30435 30.0371 1.30435 30.3917V31.9715L17.8558 3.68219L16.2613 0.963198C16.0812 0.656105 16.1881 0.26343 16.5 0.0861284C16.8119 -0.0911722 17.2108 0.0140415 17.3909 0.321134L18.6155 2.40926L19.8735 0.315282C20.0568 0.0100959 20.4568 -0.090951 20.7668 0.0895561C21.0768 0.270081 21.1794 0.663847 20.9961 0.96905L19.6168 3.26476C23.3561 4.14521 30.7166 5.52742 37.6545 3.94972L36.0874 1.27737C35.9073 0.970282 36.0142 0.577608 36.3261 0.400305C36.638 0.223004 37.0369 0.328216 37.217 0.635311L38.6522 3.0826L40.0874 0.635311C40.2675 0.328216 40.6663 0.223004 40.9783 0.400305C41.2902 0.577608 41.397 0.970282 41.217 1.27737L39.4052 4.36672L56.3886 33.3268L58.8866 30.8676C59.1413 30.6169 59.5543 30.6169 59.809 30.8676C60.0637 31.1183 60.0637 31.5249 59.809 31.7756L56.901 34.6385V36.3843C56.901 36.7389 56.609 37.0264 56.2488 37.0264C55.8886 37.0264 55.5966 36.7389 55.5966 36.3843ZM35.9548 31.9763V30.3917C35.9548 30.0371 36.2468 29.7497 36.607 29.7497C36.9672 29.7497 37.2592 30.0371 37.2592 30.3917V33.7305H55.1192L38.3349 5.10986C31.3544 6.80727 23.9635 5.56423 19.9334 4.65666L35.9548 31.9763ZM1.78049 33.7305H6.03983C10.1598 30.6293 13.1363 25.4881 15.0977 21.0657C16.0868 18.8354 16.8077 16.8112 17.2814 15.3652C17.5181 14.6425 17.6931 14.0646 17.8092 13.6766C17.8664 13.4854 17.9118 13.3321 17.942 13.2349C17.9557 13.191 17.9723 13.1384 17.9883 13.097C17.9927 13.0856 18.0004 13.0661 18.011 13.0438C18.0129 13.0397 18.0453 12.9659 18.1093 12.8919C18.1227 12.8764 18.2518 12.717 18.4934 12.6749C18.6105 12.665 18.8447 12.709 18.9537 12.763C19.0328 12.8203 19.1445 12.9423 19.1807 13.0003C19.2408 13.1088 19.2527 13.207 19.2555 13.2289C19.2568 13.2392 19.2578 13.2491 19.2586 13.2582C19.2591 13.2615 19.2598 13.2653 19.2606 13.2698C19.2656 13.2968 19.2742 13.3389 19.2871 13.3971C19.3128 13.5127 19.3528 13.679 19.4079 13.8913C19.5178 14.3153 19.6858 14.9146 19.9156 15.647C20.3753 17.1121 21.08 19.1025 22.0579 21.2817C23.9957 25.5997 26.9724 30.5815 31.177 33.7305H35.4774L18.6094 4.96707L1.78049 33.7305ZM18.5228 15.7593C18.04 17.2332 17.3042 19.2995 16.293 21.5795C14.5013 25.6195 11.8128 30.4059 8.07575 33.7305H29.128C25.3335 30.4046 22.6435 25.7643 20.8648 21.8007C19.8627 19.5676 19.141 17.5292 18.6693 16.026C18.6296 15.8995 18.5919 15.7767 18.5557 15.6579C18.5448 15.6914 18.534 15.7252 18.5228 15.7593ZM19.2609 13.3128C19.2609 13.3041 19.2605 13.2958 19.2602 13.2883C19.2606 13.2984 19.2609 13.3067 19.2609 13.3128Z"
        fill="var(--tent-outline)"
      />
    </svg>
    """
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
