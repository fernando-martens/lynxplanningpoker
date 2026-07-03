defmodule Lynxplanningpoker.Repo.Migrations.AddNameCustomizedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name_customized, :boolean, default: false, null: false
    end
  end
end
