defmodule Lynxplanningpoker.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :name, :string
    field :vote, :integer
    field :vote_changed_after_reveal, :boolean, default: false
    field :is_host, :boolean, default: false
    field :has_voted, :boolean, virtual: true, default: false
    belongs_to :room, Lynxplanningpoker.Rooms.Room, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:room_id, :name, :vote, :vote_changed_after_reveal, :is_host])
    |> validate_required([:room_id, :name])
    |> foreign_key_constraint(:room_id)
  end
end
