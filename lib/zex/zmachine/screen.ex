defmodule Zex.ZMachine.Screen do
  alias Zex.ZMachine.Screen

  defstruct [:line]

  def new() do
    %Screen{line: ""}
  end

  def print(screen, s) do
    s = String.replace(s, "\r", "\n")
    # IO.puts("- print line=#{inspect(screen.line)} s=#{inspect(s)}")
    screen = %Screen{line: screen.line <> s}
    flush(screen)
  end

  def flush(screen) do
    case :binary.match(screen.line, "\n") do
      :nomatch -> screen
      {pos, _} ->
        out = binary_part(screen.line, 0, pos)
        line = binary_part(screen.line, pos + 1, byte_size(screen.line) - pos - 1)
        # IO.puts("- flush out=#{inspect(out)} line=#{inspect(line)}")
        IO.puts(out)
        screen = %Screen{line: line}
        flush(screen)
    end
  end
end
