defmodule Zex do
  alias Zex.ZMachine
  alias Zex.ZMachine.Memory

  def run do
    z = ZMachine.load!("zork1.dat")
    # z = %ZMachine{z | debug: true}
    z = ZMachine.runLoop(z)
    z = ZMachine.processInput(z, "open mailbox")
    z = ZMachine.processInput(z, "take leaflet")
    z = ZMachine.processInput(z, "read it")
    z = ZMachine.processInput(z, "go north")
    z = ZMachine.processInput(z, "go east")
    z = ZMachine.processInput(z, "open window")
    z = ZMachine.processInput(z, "enter house")
    z = ZMachine.processInput(z, "w")
    z = ZMachine.processInput(z, "take all")
    z = ZMachine.processInput(z, "move rug")
    z = ZMachine.processInput(z, "open trap door")
    z = ZMachine.processInput(z, "go down")
    z = ZMachine.processInput(z, "what is a grue?")
    z = ZMachine.processInput(z, "turn on lantern")
    z = ZMachine.processInput(z, "n")
    z = ZMachine.processInput(z, "kill troll")
    z = ZMachine.processInput(z, "kill troll")
    _ = z
  end

  def t do
    z = ZMachine.load!("zork1.dat")
    textAddr = 30000
    parseAddr = 31000
    memory = Memory.putByte(z.memory, textAddr, 100)
    memory = Memory.putByte(memory, parseAddr, 100)
    _ = memory
    s = " what  ,    is,,\"a\", grue?"
    IO.puts("input is [#{s}]")
    case Memory.tokenize(memory, s, textAddr, parseAddr) do
      {:ok, memory} ->
        str = Memory.getString(memory, textAddr + 1)
        IO.puts(str <> "|")
        nwords = Memory.getByte(memory, parseAddr + 1)
        IO.puts("nwords #{nwords}")
        printWords(memory, textAddr, parseAddr + 2, nwords)
      res -> IO.puts(inspect(res))
    end
  end

  def printWords(_memory, _textAddr, _addr, 0) do
  end

  def printWords(memory, textAddr, addr, count) do
    dictAddr = Memory.getWord(memory, addr)
    textLen = Memory.getByte(memory, addr + 2)
    textOff = Memory.getByte(memory, addr + 3)
    entry = if dictAddr == 0 do "?" else Memory.getZString(memory, dictAddr) end
    text = Memory.getString(memory, textAddr + textOff, textLen)
    IO.puts("text=[#{text}] entry=[#{entry}]")
    printWords(memory, textAddr, addr + 4, count - 1)
  end

  def dump do
    z = ZMachine.load!("zork1.dat")
    Enum.each(27237..27240, fn a -> IO.puts("#{a} -> #{Memory.getByte(z.memory, a)}") end)
  end
end
