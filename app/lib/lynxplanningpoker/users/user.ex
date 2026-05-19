defmodule Lynxplanningpoker.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Lynxplanningpoker.Decks

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :name, :string
    field :vote, :string
    field :vote_value, :integer
    field :vote_changed_after_reveal, :boolean, default: false
    field :is_host, :boolean, default: false
    field :has_voted, :boolean, virtual: true, default: false
    belongs_to :room, Lynxplanningpoker.Rooms.Room, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for updating an existing user. Does NOT permit `:is_host` — host
  status is assigned only at creation via `creation_changeset/2`, so a malicious
  payload reaching `update_user/2` cannot escalate privileges.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:room_id, :name, :vote, :vote_changed_after_reveal])
    |> validate_required([:room_id, :name])
    |> validate_length(:name, max: 20)
    |> derive_vote_value()
    |> foreign_key_constraint(:room_id)
  end

  @doc """
  Changeset for creating a new user. Permits `:is_host` because the host flag
  is set by trusted server code (`RoomController.create/2`) when the room is
  first created.
  """
  def creation_changeset(user, attrs) do
    user
    |> cast(attrs, [:room_id, :name, :vote, :vote_changed_after_reveal, :is_host])
    |> validate_required([:room_id, :name])
    |> validate_length(:name, max: 20)
    |> derive_vote_value()
    |> foreign_key_constraint(:room_id)
  end

  defp derive_vote_value(changeset) do
    case fetch_change(changeset, :vote) do
      {:ok, label} -> put_change(changeset, :vote_value, Decks.numeric_value(label))
      :error -> changeset
    end
  end
end
