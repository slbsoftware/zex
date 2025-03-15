defmodule Zex.ZMachine.SavedGame do
  use Ecto.Schema

  schema "saved_games" do
    field :game_id, :string
    field :user_id, :string
    field :save_num, :integer
    field :game_state, :map
    field :stamp, :utc_datetime
    field :screen, :string
    field :location, :string
    field :score, :integer
    field :turns, :integer
    field :name, :string
    field :descrip, :string
  end
end
