defmodule Lynxplanningpoker.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :country, :string, size: 2, null: false
      add :count, :integer, default: 0, null: false
    end

    create unique_index(:page_views, [:date, :country])
  end
end
