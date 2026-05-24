defmodule Lynxplanningpoker.Repo.Migrations.RemoveIsActiveFromRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      remove :is_active, :boolean, default: false, null: false
    end
  end
end
