defmodule Lynxplanningpoker.Rooms do
  @moduledoc """
  The Rooms context.
  """

  import Ecto.Query, warn: false
  alias Lynxplanningpoker.Repo

  alias Lynxplanningpoker.Rooms.Room

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms do
    Repo.all(Room)
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(123)
      %Room{}

      iex> get_room!(456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room and broadcasts the change to room subscribers.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
    |> notify_room_update()
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    case Repo.delete(room) do
      {:ok, deleted_room} = result ->
        Phoenix.PubSub.broadcast(
          Lynxplanningpoker.PubSub,
          room_topic(deleted_room.id),
          {:room_deleted, deleted_room.id}
        )

        result

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  @doc """
  Subscribes to room updates for a given room.
  """
  def subscribe_to_room(room_id) do
    Phoenix.PubSub.subscribe(Lynxplanningpoker.PubSub, room_topic(room_id))
  end

  defp notify_room_update({:ok, %Room{} = room} = result) do
    Phoenix.PubSub.broadcast(
      Lynxplanningpoker.PubSub,
      room_topic(room.id),
      {:room_updated, room}
    )

    result
  end

  defp notify_room_update({:error, _} = error), do: error

  defp room_topic(room_id), do: "room:#{room_id}"
end
