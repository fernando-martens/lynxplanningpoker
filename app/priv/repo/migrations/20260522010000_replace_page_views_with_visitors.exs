defmodule Lynxplanningpoker.Repo.Migrations.ReplacePageViewsWithVisitors do
  @moduledoc """
  Switches analytics from per-day page-view counters to per-day **unique
  visitor** counters. The old `page_views` table is dropped (its rows are
  just early aggregate counts — no personal data is lost). The new
  `visitors` table holds one row per `(date, visitor_hash)`: a unique daily
  fingerprint produced from IP + User-Agent + date + a server secret. See
  `Lynxplanningpoker.Analytics`.
  """
  use Ecto.Migration

  def up do
    drop table(:page_views)

    create table(:visitors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :visitor_hash, :string, size: 64, null: false
      add :country, :string, size: 2, null: false
    end

    create unique_index(:visitors, [:date, :visitor_hash])
  end

  def down do
    drop table(:visitors)

    create table(:page_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :country, :string, size: 2, null: false
      add :count, :integer, default: 0, null: false
    end

    create unique_index(:page_views, [:date, :country])
  end
end
