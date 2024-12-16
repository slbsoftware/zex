defmodule Zex do
  alias Zex.ZMachine

  def run do
    z = ZMachine.load!("zork1.dat")
  	z = ZMachine.runLoop(z)
    inputLoop(z)
  end

  def inputLoop(z) do
  	case z.state do
  		:waitInput -> getInput(z)
  		:quit -> nil
  		:restart -> run()
  	end
  end

  def getInput(z) do
  	case IO.gets("") do
  		:eof -> nil
  		{:error, reason} -> IO.puts("Input error: #{reason}")
  		data ->
  			z = ZMachine.processInput(z, data)
  			inputLoop(z)
  	end
  end
end
