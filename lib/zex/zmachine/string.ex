defmodule Zex.ZMachine.StringEncoding do
  alias Zex.ZMachine.Memory
  alias Zex.ZMachine.StringEncoding

  defstruct [:memory, :addr, :str, :alphabet, :abbrev, :esc]

  # https://www.inform-fiction.org/zmachine/standards/z1point1/sect03.html

  @zcharset "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ \r0123456789.,!?_#'\"/\\-:()"

  def getZstring(memory, addr) do
    enc = %StringEncoding{memory: memory, addr: addr, str: "", alphabet: 0}
    getZstring(enc)
  end

  def getZstring(enc) do
    word = Memory.getWord(enc.memory, enc.addr)
    <<b::size(1), c1::size(5), c2::size(5), c3::size(5)>> = <<word::size(16)>>
    enc
    |> zChar(c1)
    |> zChar(c2)
    |> zChar(c3)
    |> advance(b)
  end

  def zChar(enc, c) when enc.abbrev != nil do
    abbrNo = (enc.abbrev - 1) * 32 + c
    addr = Memory.getAddrAbbrevTbl(enc.memory) + abbrNo * 2
    addr = Memory.getWord(enc.memory, addr)
    s = getZstring(enc.memory, addr * 2)
    %StringEncoding{enc | str: enc.str <> s, abbrev: nil}
  end

  def zChar(enc, c) when enc.esc == true do
    %StringEncoding{enc | esc: c}
  end

  def zChar(enc, c) when is_number(enc.esc) do
    s = <<enc.esc * 32 + c>>
    %StringEncoding{enc | str: enc.str <> s, esc: nil}
  end

  def zChar(enc, c) when c in [1, 2, 3] do
    %StringEncoding{enc | abbrev: c}
  end

  def zChar(enc, c) when c in [4, 5] do
    %StringEncoding{enc | alphabet: c - 3}
  end

  def zChar(enc, 0) do
    %StringEncoding{enc | str: enc.str <> " "}
  end

  # when alphabet is 2 and the z-char is 6, it means the next 2 z-chars will combine to form a 10 bit zscii codepoint
  def zChar(enc, 6) when enc.alphabet == 2 do
    %StringEncoding{enc | alphabet: 0, esc: true}
  end

  def zChar(enc, c) do
    zc = enc.alphabet * 26 + c - 6
    s = binary_part(@zcharset, zc, 1)
    %StringEncoding{enc | str: enc.str <> s, alphabet: 0}
  end

  def advance(enc, 0) do
    %StringEncoding{enc | addr: enc.addr + 2}
    |> getZstring()
  end

  def advance(enc, 1) do
    enc.str
  end

  def encodeWord(word) do
    addCode = fn acc, code ->
      n = elem(acc, 0) + 1
      if n < 7 do
        if code < 32 do
          acc = put_elem(acc, n, code)
          put_elem(acc, 0, n)
        else
          acc = put_elem(acc, n, 3 + div(code, 32))
          n = n + 1
          if n < 7 do
            acc = put_elem(acc, n, rem(code, 32))
            put_elem(acc, 0, n)
          else
            put_elem(acc, 0, 6)
          end
        end
      else
        acc
      end
    end

    codes = Enum.reduce(
      to_charlist(word),
      {0, 5, 5, 5, 5, 5, 5},
      fn x, acc ->
        case :binary.match(@zcharset, <<x>>) do
          :nomatch -> addCode.(acc, 0)
          {off, _} ->
            alphabet = div(off, 26)
            char = rem(off, 26)
            addCode.(acc, alphabet * 32 + 6 + char)
        end
      end
    )
    {_, c1, c2, c3, c4, c5, c6} = codes
    <<0::size(1), c1::size(5), c2::size(5), c3::size(5), 1::size(1), c4::size(5), c5::size(5), c6::size(5)>>
  end
end
