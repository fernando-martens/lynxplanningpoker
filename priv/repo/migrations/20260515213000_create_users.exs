defmodule Lynxplanningpoker.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :room_id, references(:rooms, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :vote, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:user_id])
    create index(:users, [:room_id])
  end
end
