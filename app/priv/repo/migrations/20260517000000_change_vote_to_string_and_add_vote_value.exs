defmodule Lynxplanningpoker.Repo.Migrations.ChangeVoteToStringAndAddVoteValue do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :vote
    end

    alter table(:users) do
      add :vote, :string
      add :vote_value, :integer
    end
  end

  def down do
    alter table(:users) do
      remove :vote
      remove :vote_value
    end

    alter table(:users) do
      add :vote, :integer
    end
  end
end
