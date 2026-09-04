defmodule Lynxplanningpoker.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Lynxplanningpoker.Repo
  alias Lynxplanningpoker.Users.User

  @max_users_per_room 15

  @doc """
  Maximum number of users allowed in a single room.
  """
  def max_users_per_room, do: @max_users_per_room

  @doc """
  Returns the number of users in a given room.
  """
  def count_users_by_room(room_id) do
    User
    |> where([u], u.room_id == ^room_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns true when the room already has the maximum number of users.
  """
  def room_full?(room_id) do
    count_users_by_room(room_id) >= @max_users_per_room
  end

  @doc """
  Returns true when the room still has a user holding the host role.

  A room can be host-less for a while: the host's connection dropping only
  removes them from the table, it never closes the room. `RoomController` uses
  this to decide whether a returning host may reclaim the seat.
  """
  def has_host?(room_id) do
    User
    |> where([u], u.room_id == ^room_id and u.is_host)
    |> Repo.exists?()
  end

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Lists users by room.
  """
  def list_users_by_room(room_id) do
    User
    |> where([u], u.room_id == ^room_id)
    |> order_by([u], asc: u.name)
    |> Repo.all()
  end

  @doc """
  Lists users by room as seen by a given viewer.

  When the room is not revealed, every other user's `vote` is hidden (replaced by
  `nil`) so the value never reaches the client. The viewer always sees their own
  vote. The virtual `has_voted` field always reflects whether the user has cast a
  vote, regardless of whether its value is visible.
  """
  def list_users_by_room(room_id, viewer_user_id, revealed?) do
    room_id
    |> list_users_by_room()
    |> Enum.map(fn user ->
      visible? = revealed? or user.id == viewer_user_id
      visible_vote = if visible?, do: user.vote
      visible_value = if visible?, do: user.vote_value

      %{
        user
        | vote: visible_vote,
          vote_value: visible_value,
          has_voted: not is_nil(user.vote)
      }
    end)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user and broadcasts the updated room.
  """
  def create_user(attrs) do
    %User{}
    |> User.creation_changeset(attrs)
    |> Repo.insert()
    |> notify_room_update()
  end

  @doc """
  Updates a user and broadcasts the updated room.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> notify_room_update()
  end

  @doc """
  Renames a user and broadcasts the updated room.
  """
  def rename_user(%User{} = user, attrs) do
    user
    |> User.rename_changeset(attrs)
    |> Repo.update()
    |> notify_room_update()
  end

  @doc """
  Marks a user's name as customized without changing it. Used when the user
  dismisses the onboarding name prompt ("Skip"), so it never reopens. No
  broadcast: the name did not change, so other participants have nothing to
  refresh.
  """
  def mark_name_customized(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{name_customized: true})
    |> Repo.update()
  end

  @doc """
  Deletes a user and broadcasts the updated room.
  """
  def delete_user(%User{} = user) do
    repo_result = Repo.delete(user)
    notify_room_update(repo_result, user.room_id)
  end

  @doc """
  Returns a changeset for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Subscribes to updates for a room.
  """
  def subscribe_to_room(room_id) do
    Phoenix.PubSub.subscribe(Lynxplanningpoker.PubSub, room_topic(room_id))
  end

  defp notify_room_update({:ok, %User{} = user} = result) do
    broadcast_room_update(user.room_id)
    result
  end

  defp notify_room_update({:error, _} = error), do: error

  defp notify_room_update({:ok, _user} = result, room_id) do
    broadcast_room_update(room_id)
    result
  end

  defp notify_room_update({:error, _} = error, _room_id), do: error

  defp broadcast_room_update(room_id) do
    Phoenix.PubSub.broadcast(
      Lynxplanningpoker.PubSub,
      room_topic(room_id),
      {:users_updated, room_id}
    )
  end

  defp room_topic(room_id), do: "room:#{room_id}"
end
