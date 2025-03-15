defmodule Zex.ZMachine.StackFrame do
  alias Zex.ZMachine.StackFrame

  @derive Jason.Encoder
  defstruct [:nextIp, :locals, :stack, :storeReturn]

  def new(nextIp, storeReturn) do
    %StackFrame{
      nextIp: nextIp,
      locals: %{},
      stack: [],
      storeReturn: storeReturn,
    }
  end

  def fromJson(decoded) do
    %StackFrame{
      nextIp: decoded["nextIp"],
      locals: Zex.withIntKeys(decoded["locals"]),
      stack: decoded["stack"],
      storeReturn: decoded["storeReturn"],
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

defmodule Zex.ZMachine.Stack do
  alias Zex.ZMachine.StackFrame

  def new() do
    [StackFrame.new(nil, nil)]
  end

  def fromJson(decoded) do
    s = Enum.map(
      decoded,
      fn f -> StackFrame.fromJson(f) end
    )
    IO.puts("s = #{inspect(s)}")
    s
  end

  def getVariable(stack, 0) do
    frame = List.first(stack)
    {frame, value} = StackFrame.pop(frame)
    stack = List.replace_at(stack, 0, frame)
    {stack, value}
  end

  def getVariable(stack, v) do
    frame = List.first(stack)
    value = StackFrame.getLocal(frame, v)
    {stack, value}
  end

  def setVariable(stack, 0, value) do
    frame = List.first(stack)
    frame = StackFrame.push(frame, value)
    List.replace_at(stack, 0, frame)
  end

  def setVariable(stack, v, value) do
    frame = List.first(stack)
    frame = StackFrame.putLocal(frame, v, value)
    List.replace_at(stack, 0, frame)
  end
end
