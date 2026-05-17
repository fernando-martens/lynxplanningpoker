defmodule Lynxplanningpoker.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Lynxplanningpoker.Repo
  alias Lynxplanningpoker.Users.User

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
    |> User.changeset(attrs)
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
