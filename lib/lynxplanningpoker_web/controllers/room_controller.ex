defmodule LynxplanningpokerWeb.RoomController do
  use LynxplanningpokerWeb, :controller

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Rooms.Room
  alias Lynxplanningpoker.Users

  def new(conn, _params) do
    changeset = Rooms.change_room(%Room{})
    render(conn, :new, changeset: changeset, action: ~p"/rooms")
  end

  def create(conn, %{"room" => room_params}) do
    # Extract the user name from params (not part of room schema)
    user_name = room_params["name"]
    # Remove name from room_params since Room schema doesn't have it
    room_params = Map.drop(room_params, ["name"])

    case Rooms.create_room(room_params) do
      {:ok, room} ->
        # Create a user with the provided name in this room
        case Users.create_user(%{
               room_id: room.id,
               name: user_name
             }) do
          {:ok, user} ->
            conn
            |> put_session(:current_user_id, user.id)
            |> redirect(to: ~p"/rooms/#{room}")

          {:error, _changeset} ->
            conn
            |> redirect(to: ~p"/rooms/#{room}")
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, action: ~p"/rooms")
    end
  end

  def show(conn, %{"id" => id}) do
    _room = Rooms.get_room!(id)
    render(conn, :invite, room_id: id)
  end

  def acceptInvite(conn, %{"id" => room_id, "name" => user_name}) do
    room = Rooms.get_room!(room_id)

    case Users.create_user(%{
           room_id: room.id,
           name: user_name
         }) do
      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> redirect(to: ~p"/rooms/#{room}")

      {:error, _changeset} ->
        render(conn, :invite, room_id: room_id)
    end
  end
end
