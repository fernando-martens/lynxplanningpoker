defmodule Lynxplanningpoker.Repo.Migrations.AddRevealedToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :revealed, :boolean, default: false, null: false
    end
  end
end
