defmodule Lynxplanningpoker.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :user_id, :binary_id
    field :name, :string
    field :vote, :integer
    belongs_to :room, Lynxplanningpoker.Rooms.Room, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:user_id, :room_id, :name, :vote])
    |> validate_required([:user_id, :room_id, :name])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:room_id)
  end
end
