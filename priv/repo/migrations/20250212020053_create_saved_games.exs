defmodule Zex.Repo.Migrations.CreateSavedGames do
  use Ecto.Migration

  def change do
    create table(:saved_games) do
      add :game_id, :text, null: false
      add :user_id, :text
      add :save_num, :integer
      add :game_state, :map, null: false
      add :stamp, :utc_datetime, null: false
      add :screen, :text, null: false
      add :location, :text, null: false
      add :score, :integer, null: false
      add :turns, :integer, null: false
      add :name, :text
      add :descrip, :text
    end

    create index("saved_games", [:game_id], unique: true)
  end
end
