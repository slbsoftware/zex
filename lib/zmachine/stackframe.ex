defmodule Zex.ZMachine.StackFrame do
  alias Zex.ZMachine.StackFrame
  
  defstruct [:nextIp, :locals, :stack, :storeReturn]

  def new(nextIp, storeReturn) do
    %StackFrame{
      nextIp: nextIp,
      locals: %{},
      stack: [],
      storeReturn: storeReturn,
    }
  end

  def push(frame, value) do
    %StackFrame{frame | stack: [value | frame.stack]}
  end

  def pop(frame) do
    [popped | stack] = frame.stack
    {%StackFrame{frame | stack: stack}, popped}
  end

  def getLocal(frame, v) do
    frame.locals[v - 1]
  end

  def putLocal(frame, v, value) do
    locals = Map.put(frame.locals, v - 1, value)
    %StackFrame{frame | locals: locals}
  end
end
