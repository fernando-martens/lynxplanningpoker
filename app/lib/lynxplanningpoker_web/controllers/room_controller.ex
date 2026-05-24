defmodule LynxplanningpokerWeb.RoomController do
  use LynxplanningpokerWeb, :controller

  alias Lynxplanningpoker.Rooms
  alias Lynxplanningpoker.Rooms.Room
  alias Lynxplanningpoker.Turnstile
  alias Lynxplanningpoker.Users
  alias LynxplanningpokerWeb.ClientIP
  alias LynxplanningpokerWeb.Locales

  def new(conn, _params) do
    changeset = Rooms.change_room(%Room{})

    render_new(conn, changeset)
  end

  def create(conn, %{"room" => room_params} = params) do
    # Persist the URL's locale so the (prefix-free) live room renders in the
    # language the host went through the creation flow in.
    conn = put_session(conn, :locale, conn.assigns.locale)
    user_name = room_params["name"]
    room_params = Map.drop(room_params, ["name"])
    turnstile_token = params["cf-turnstile-response"]

    case Turnstile.verify(turnstile_token, ClientIP.from_conn(conn)) do
      :ok ->
        do_create(conn, room_params, user_name)

      {:error, _reason} ->
        changeset = Rooms.change_room(%Room{}, room_params)

        conn
        |> put_flash(:error, gettext("Please complete the human verification before continuing."))
        |> render_new(changeset)
    end
  end

  defp render_new(conn, changeset) do
    conn
    |> assign(:page_title, gettext("Create a Room · Lynx Poker"))
    |> assign(:noindex, true)
    |> render(:new,
      changeset: changeset,
      action: Locales.localized_path(conn.assigns.locale, ~p"/rooms"),
      turnstile_site_key: Turnstile.site_key()
    )
  end

  defp render_invite(conn, room_id) do
    conn
    |> assign(:page_title, gettext("Join the Planning Room · Lynx Poker"))
    |> assign(:noindex, true)
    |> render(:invite,
      action: Locales.localized_path(conn.assigns.locale, ~p"/rooms/invite/#{room_id}")
    )
  end

  defp do_create(conn, room_params, user_name) do
    case Rooms.create_room(room_params) do
      {:ok, room} ->
        cleanup_previous_session(conn)

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
        render_new(conn, changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    cond do
      is_nil(Rooms.get_room(id)) ->
        conn
        |> put_flash(:error, gettext("This room does not exist or has already ended."))
        |> redirect(to: home_path(conn))

      already_in_room?(conn, id) ->
        redirect(conn, to: ~p"/rooms/#{id}")

      Users.room_full?(id) ->
        conn
        |> put_flash(:error, room_full_message())
        |> redirect(to: home_path(conn))

      true ->
        render_invite(conn, id)
    end
  end

  def accept_invite(conn, %{"id" => room_id, "name" => user_name}) do
    # Persist the URL's locale so the (prefix-free) live room renders in the
    # language the guest went through the invite flow in.
    conn = put_session(conn, :locale, conn.assigns.locale)

    case Rooms.get_room(room_id) do
      nil ->
        conn
        |> put_flash(:error, gettext("This room does not exist or has already ended."))
        |> redirect(to: home_path(conn))

      room ->
        if Users.room_full?(room.id) and not already_in_room?(conn, room.id) do
          conn
          |> put_flash(:error, room_full_message())
          |> redirect(to: home_path(conn))
        else
          do_accept_invite(conn, room, user_name)
        end
    end
  end

  defp room_full_message do
    gettext("This room is full (maximum %{max} players).",
      max: Users.max_users_per_room()
    )
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
        render_invite(conn, room.id)
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

  # The home page in the visitor's current locale. Every redirect out of the
  # room flow uses this so a user browsing in English isn't bounced to the
  # prefix-free (default-locale) home page.
  defp home_path(conn), do: Locales.localized_path(conn.assigns.locale, "/")

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

    redirect(conn, to: home_path(conn))
  end
end
