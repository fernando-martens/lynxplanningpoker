defmodule Lynxplanningpoker.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Lynxplanningpoker.Decks

  @max_name_length 20

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :name, :string
    field :vote, :string
    field :vote_value, :integer
    field :vote_changed_after_reveal, :boolean, default: false
    field :is_host, :boolean, default: false
    field :name_customized, :boolean, default: false
    field :has_voted, :boolean, virtual: true, default: false
    belongs_to :room, Lynxplanningpoker.Rooms.Room, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Longest display name a participant may have. Exposed so callers that take a
  name from elsewhere — the invite form's remembered name, say — can drop an
  implausible value instead of pushing it into a changeset that will reject it.
  """
  def max_name_length, do: @max_name_length

  @doc """
  Changeset for updating an existing user. Only permits voting-related fields
  (`:vote`, `:vote_changed_after_reveal`). Identity fields (`:room_id`,
  `:name`) and `:is_host` are set exclusively at creation via
  `creation_changeset/2`, so a malicious payload reaching `update_user/2`
  cannot move a user between rooms, rename them, or escalate privileges.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:vote, :vote_changed_after_reveal])
    |> validate_inclusion(:vote, Decks.labels())
    |> derive_vote_value()
  end

  @doc """
  Changeset for renaming an existing user. Only permits `:name`, and marks
  `:name_customized` so the in-room onboarding prompt never reopens once the
  user has chosen a name. Keeps `:vote`, `:room_id`, `:is_host` out of reach so
  a payload reaching `rename_user/2` cannot tamper with identity, privileges,
  or room membership — `:name_customized` is a behavioural flag, not a
  privilege, so setting it here is safe.
  """
  def rename_changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: @max_name_length)
    |> put_change(:name_customized, true)
  end

  @doc """
  Changeset for creating a new user. Permits `:is_host` because the host flag
  is set by trusted server code (`RoomController.create/2` when the room is
  first created, `accept_invite/2` when a returning host reclaims a seat no one
  else holds) — never from a client-supplied value. `:name_customized` is a
  behavioural flag, not a privilege: it is set when the visitor rejoins under a
  name they had already chosen, so the room does not ask for it a second time.
  """
  def creation_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :room_id,
      :name,
      :vote,
      :vote_changed_after_reveal,
      :is_host,
      :name_customized
    ])
    |> validate_required([:room_id, :name])
    |> validate_length(:name, max: @max_name_length)
    |> validate_inclusion(:vote, Decks.labels())
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
