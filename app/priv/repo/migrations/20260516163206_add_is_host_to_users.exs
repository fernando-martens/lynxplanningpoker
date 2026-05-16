defmodule Lynxplanningpoker.Repo.Migrations.AddIsHostToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_host, :boolean, default: false, null: false
    end
  end
end
