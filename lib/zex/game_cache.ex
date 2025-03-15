defmodule Zex.CachedGame do
  defstruct [
    :game,
    :accessed_at,
  ]
end

defmodule Zex.GameCache do
  import Ecto.Query

  alias Zex.CachedGame
  alias Zex.Repo
  alias Zex.ZMachine
  alias Zex.ZMachine.SavedGame

  use Agent

  def start_link(_initial_value) do
    state = %{
      zork: File.read!("zork1.dat")
    }
    Agent.start_link(fn -> state end, name: __MODULE__)
  end

  def get_current_game(user_id) do
    cg = Agent.get(__MODULE__, & &1[user_id])
    if cg do
      cg.game
    else
      sg = Repo.get_by(SavedGame, game_id: user_id <> ":sess")
      cg = %CachedGame{
        game: restore_zmachine(user_id, sg),
        accessed_at: DateTime.utc_now(),
      }
      Agent.update(__MODULE__, &Map.put(&1, cg.game.user_id, cg))
      cg.game
    end
  end

  def update_current_game(z) do
    flush_games()
    cg = %CachedGame{
      game: z,
      accessed_at: DateTime.utc_now(),
    }
    Agent.update(__MODULE__, &Map.put(&1, cg.game.user_id, cg))
    insert_game(z, nil, nil, nil)
  end

  def list_games(_user_id) do
  end

  def save_game(z, name, descrip) do
    insert_game(z, next_save_num(z.user_id), name, descrip)
  end

  def restore_game(_save_id) do
  end

  def restore_zmachine(user_id, sg) do
    zorkData = Agent.get(__MODULE__, &Map.get(&1, :zork))
    if sg do
      ZMachine.restore_game(
        sg.user_id,
        zorkData,
        Zex.withIntKeys(sg.game_state["memory"]),
        sg.game_state["curIp"],
        sg.game_state["stack"],
        sg.game_state["rand"],
        sg.game_state["textBuffer"],
        sg.game_state["parseBuffer"],
        sg.screen
      )
    else
      ZMachine.new_game(user_id, zorkData)
      |> ZMachine.runLoop()
    end
  end

  def flush_games() do
  end

  def next_save_num(user_id) do
    [n | _] = Repo.all(
      from(
        game in SavedGame,
        where: game.user_id == ^user_id,
        select: max(game.save_num) |> coalesce(0)
      )
    )
    n + 1
  end

  def insert_game(z, save_num, name, descrip) do
    game_id = if save_num do
      z.user_id <> ":" <> Integer.to_string(save_num)
    else
      z.user_id <> ":sess"
    end
    row = %SavedGame{
      game_id: game_id,
      user_id: z.user_id,
      save_num: save_num,
      game_state: %{
        memory: z.memory.written,
        curIp: z.curIp,
        stack: z.stack,
        rand: z.rand,
        textBuffer: z.textBuffer,
        parseBuffer: z.parseBuffer,
      },
      stamp: DateTime.truncate(DateTime.utc_now(), :second),
      screen: z.screen.screen,
      location: ZMachine.location(z),
      score: ZMachine.score(z),
      turns: ZMachine.turns(z),
      name: name,
      descrip: descrip,
    }
    if save_num do
      Repo.insert!(row)
    else
      Repo.insert!(
        row,
        on_conflict: :replace_all,
        conflict_target: :game_id
      )
    end
  end
end
