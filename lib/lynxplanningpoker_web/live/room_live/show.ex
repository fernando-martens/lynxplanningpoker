defmodule LynxplanningpokerWeb.RoomLive.Show do
  use LynxplanningpokerWeb, :live_view

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users

  @cards [0, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, "?"]

  @impl true
  def mount(%{"id" => id}, session, socket) do
    room = Rooms.get_room!(id)
    current_user_id = session["current_user_id"]
    users = Users.list_users_by_room(id, current_user_id, room.revealed)
    current_user = current_user_id && Enum.find(users, &(&1.id == current_user_id))

    if current_user do
      if connected?(socket) do
        Users.subscribe_to_room(id)
        Rooms.subscribe_to_room(id)
      end

      socket =
        socket
        |> assign(:room, room)
        |> assign(:users, users)
        |> assign(:current_user_id, current_user.id)
        |> assign(:current_user, current_user)
        |> assign(:cards, @cards)

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/rooms/invite/#{id}")}
    end
  end

  @impl true
  def handle_event("vote", %{"card" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket}

      current_user ->
        clicked_value =
          case Integer.parse(value) do
            {int, ""} -> int
            _ -> nil
          end

        vote_value = if current_user.vote == clicked_value, do: nil, else: clicked_value

        attrs =
          if socket.assigns.room.revealed do
            %{vote: vote_value, vote_changed_after_reveal: true}
          else
            %{vote: vote_value}
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
             put_flash(socket, :error, "Não foi possível registrar seu voto. Tente novamente.")}
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

      {:noreply,
       socket
       |> put_flash(:info, "Planning encerrada.")
       |> push_navigate(to: ~p"/")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("leave_room", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Você saiu da sala.")
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_info({:room_deleted, room_id}, socket) do
    if socket.assigns.room.id == room_id do
      {:noreply,
       socket
       |> put_flash(:info, "A sala foi encerrada pelo host.")
       |> push_navigate(to: ~p"/")}
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

  defp user_positions(users) do
    total = length(users)

    Enum.with_index(users)
    |> Enum.map(fn {user, i} ->
      angle = -:math.pi() / 2 + 2 * :math.pi() / total * i
      x = 50 + 40 * :math.cos(angle)
      y = 50 + 36 * :math.sin(angle)
      {user, Float.round(x, 2), Float.round(y, 2)}
    end)
  end

  defp card_selected?(current_user, card) do
    current_user && to_string(current_user.vote) == to_string(card)
  end

  defp vote_average(users) do
    numeric_votes = for %{vote: v} <- users, is_integer(v), do: v

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
                    <span class="room-user-vote-num">{to_string(user.vote)}</span>
                  <% user.has_voted -> %>
                    <.paw_icon />
                  <% true -> %>
                    <span class="room-user-initials">{initials(user.name)}</span>
                <% end %>
                <%= if @room.revealed and user.vote_changed_after_reveal do %>
                  <span class="room-user-edit-badge" title="Voto alterado após revelar">
                    <.pencil_icon />
                  </span>
                <% end %>
              </div>
              <span class="room-user-name">{user.name}</span>
            </div>
          <% end %>

          <%!-- Campfire at center --%>
          <div class="room-campfire-wrap">
            <div id="campfire">
              <div id="wood"><span></span></div>
              <div id="fire"></div>
            </div>
            <%= if @room.revealed do %>
              <div class="room-average" aria-label="Média dos votos">
                <span class="room-average-label">Média</span>
                <span class="room-average-value">{vote_average(@users)}</span>
              </div>
            <% else %>
              <button phx-click="reveal" class="room-reveal-btn">
                Reveal
              </button>
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
                phx-value-card={to_string(card)}
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
      <circle cx="6" cy="7" r="2" />
      <circle cx="12" cy="5" r="2" />
      <circle cx="18" cy="7" r="2" />
      <circle cx="4" cy="12" r="1.5" />
      <path d="M12 10c-3.5 0-6 2-6 5s2 5 6 5 6-2 6-5-2.5-5-6-5z" />
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
