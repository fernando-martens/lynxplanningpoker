defmodule Lynxplanningpoker.Repo.Migrations.AddVoteChangedAfterRevealToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :vote_changed_after_reveal, :boolean, default: false, null: false
    end
  end
end
