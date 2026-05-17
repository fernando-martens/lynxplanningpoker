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
        cleanup_previous_session(conn)

        # Create a user with the provided name in this room as the host
        case Users.create_user(%{
               room_id: room.id,
               name: user_name,
               is_host: true
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
    cond do
      is_nil(Rooms.get_room(id)) ->
        conn
        |> put_flash(:error, gettext("This room does not exist or has already ended."))
        |> redirect(to: ~p"/")

      already_in_room?(conn, id) ->
        redirect(conn, to: ~p"/rooms/#{id}")

      true ->
        render(conn, :invite, room_id: id)
    end
  end

  def acceptInvite(conn, %{"id" => room_id, "name" => user_name}) do
    case Rooms.get_room(room_id) do
      nil ->
        conn
        |> put_flash(:error, gettext("This room does not exist or has already ended."))
        |> redirect(to: ~p"/")

      room ->
        do_accept_invite(conn, room, user_name)
    end
  end

  defp do_accept_invite(conn, room, user_name) do
    cleanup_previous_session(conn)

    case Users.create_user(%{
           room_id: room.id,
           name: user_name
         }) do
      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> redirect(to: ~p"/rooms/#{room}")

      {:error, _changeset} ->
        render(conn, :invite, room_id: room.id)
    end
  end

  defp already_in_room?(conn, room_id) do
    with user_id when not is_nil(user_id) <- get_session(conn, :current_user_id),
         user when not is_nil(user) <- safe_get_user(user_id) do
      user.room_id == room_id
    else
      _ -> false
    end
  end

  defp cleanup_previous_session(conn) do
    with user_id when not is_nil(user_id) <- get_session(conn, :current_user_id),
         user when not is_nil(user) <- safe_get_user(user_id) do
      if user.is_host do
        case Rooms.get_room(user.room_id) do
          nil -> :ok
          room -> Rooms.delete_room(room)
        end
      else
        Users.delete_user(user)
      end
    end

    :ok
  end

  defp safe_get_user(user_id) do
    Users.get_user!(user_id)
  rescue
    Ecto.NoResultsError -> nil
  end

  def leave(conn, _params) do
    case get_session(conn, :current_user_id) do
      nil ->
        :ok

      user_id ->
        try do
          user_id |> Users.get_user!() |> Users.delete_user()
        rescue
          Ecto.NoResultsError -> :ok
        end
    end

    conn = delete_session(conn, :current_user_id)

    conn =
      if Phoenix.Flash.get(conn.assigns.flash, :info) do
        conn
      else
        put_flash(conn, :info, gettext("You left the room."))
      end

    redirect(conn, to: ~p"/")
  end
end
