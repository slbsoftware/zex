defmodule ZexWeb.GameLive do
  alias Zex.GameCache
  alias Zex.ZMachine
  alias Zex.ZMachine.Screen

  use ZexWeb, :live_view

  def render(assigns) do
    ~H"""
    <div id="top">
      <div id="topleft"><%= @location %></div>
      <div id="topright">Score: <%= @score %> &nbsp; Moves: <%= @turns %></div>
    </div>
    <div id="main"><div id="maintext" phx-hook="Hook"><%= raw @output %></div></div>
    <div id="bottom">
      <form id="playerform" phx-submit="submit">
        &gt; <input id="playerinput" type="text" name="cmd" autofocus autocomplete="off" />
      </form>
    </div>
    """
  end

  def mount(_params, session, socket) do
    sid = Map.get(session, "session_id")
    z = GameCache.get_current_game(sid)
    {:ok, game_assigns(z, sid, socket)}
  end

  def handle_event("submit", %{"cmd" => cmd}, socket) do
    IO.puts("cmd = {cmd}")
    sid = socket.assigns[:session_id]
    z = GameCache.get_current_game(sid)
    z = ZMachine.processInput(z, cmd)
    GameCache.update_current_game(z)
    {:noreply, game_assigns(z, sid, socket)}
  end

  def game_assigns(z, sid, socket) do
    assign(
      socket,
      session_id: sid,
      location: ZMachine.location(z),
      turns: ZMachine.turns(z),
      score: ZMachine.score(z),
      output: Screen.html(z.screen)
    )
  end
end
