defmodule Zex.ZMachine.Screen do
  alias Zex.ZMachine.Screen

  defstruct [:screen]

  def new(screen \\ "") do
    %Screen{screen: screen}
  end

  def print(screen, s) do
    s = String.replace(s, "&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\r", "<br>")
    %Screen{screen: screen.screen <> s}
  end

  def html(screen) do
    screen.screen
    |> String.trim_trailing(" ")
    |> String.trim_trailing("&gt;")
  end
end
