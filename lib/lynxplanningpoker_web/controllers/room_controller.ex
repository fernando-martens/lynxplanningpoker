defmodule LynxplanningpokerWeb.RoomController do
  use LynxplanningpokerWeb, :controller

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Rooms.Room

  def index(conn, _params) do
    changeset = Rooms.change_room(%Room{})
    render(conn, :index, changeset: changeset, action: ~p"/rooms/new")
  end

  def new(conn, _params) do
    changeset = Rooms.change_room(%Room{})
    render(conn, :index, changeset: changeset, action: ~p"/rooms/new")
  end

  def create(conn, %{"room" => room_params}) do
    case Rooms.create_room(room_params) do
      {:ok, room} ->
        conn
        |> put_flash(:info, "Room created successfully.")
        |> redirect(to: ~p"/rooms/#{room}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :index, changeset: changeset, action: ~p"/rooms/new")
    end
  end

  def show(conn, %{"id" => id}) do
    room = Rooms.get_room!(id)
    render(conn, :show, room: room)
  end
end
