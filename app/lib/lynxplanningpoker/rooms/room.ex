defmodule Lynxplanningpoker.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "rooms" do
    field :is_active, :boolean, default: false
    field :revealed, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:is_active, :revealed])
    |> validate_required([:is_active, :revealed])
  end
end
