defmodule LynxplanningpokerWeb.RoomLive.Show do
  use LynxplanningpokerWeb, :live_view

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Users

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Users.subscribe_to_room(id)

    room = Rooms.get_room!(id)
    users = Users.list_users_by_room(id)

    socket =
      socket
      |> assign(:room, room)
      |> assign(:users, users)

    {:ok, socket}
  end

  @impl true
  def handle_info({:users_updated, room_id}, socket) do
    if socket.assigns.room.id == room_id do
      {:noreply, assign(socket, :users, Users.list_users_by_room(room_id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.room_header />
    <div class="flex flex-col items-center justify-center h-screen">
      <div id="campfire">
        <div id="wood"><span></span></div>
        
        <div id="fire"></div>
      </div>
      
      <%= for user <- @users do %>
        <div class="text-lg">{user.name} {if user.vote, do: to_string(user.vote), else: "-"}</div>
      <% end %>
    </div>
    """
  end
end
