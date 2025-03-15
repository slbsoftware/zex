defmodule Zex.ZMachine do
  alias Zex.GameCache
  alias Zex.ZMachine
  alias Zex.ZMachine.Memory
  alias Zex.ZMachine.Screen
  alias Zex.ZMachine.Stack
  alias Zex.ZMachine.StackFrame

  import Bitwise, only: [band: 2, bor: 2, bnot: 1, bsl: 2, bsr: 2]

  @hasStoreByte %{
    0x21 => true,
    0x22 => true,
    0x23 => true,
    0x24 => true,
    0x28 => true,
    0x2e => true,
    0x2f => true,
    0x48 => true,
    0x49 => true,
    0x4f => true,
    0x50 => true,
    0x51 => true,
    0x52 => true,
    0x53 => true,
    0x54 => true,
    0x55 => true,
    0x56 => true,
    0x57 => true,
    0x58 => true,
    0x59 => true,
    0x60 => true,
    0x67 => true,
  }

  @hasBranch %{
    0x05 => true,
    0x06 => true,
    0x0d => true,
    0x0f => true,
    0x20 => true,
    0x21 => true,
    0x22 => true,
    0x41 => true,
    0x42 => true,
    0x43 => true,
    0x44 => true,
    0x45 => true,
    0x46 => true,
    0x47 => true,
    0x4a => true,
    0x77 => true,
    0x7f => true,
  }

  @instructions %{
    0x00 => &ZMachine.i0_rtrue/1,
    0x01 => &ZMachine.i0_rfalse/1,
    0x02 => &ZMachine.i0_print/1,
    0x03 => &ZMachine.i0_print_ret/1,
    0x04 => &ZMachine.i0_nop/1,
    0x05 => &ZMachine.i0_save/1,
    0x06 => &ZMachine.i0_restore/1,
    0x07 => &ZMachine.i0_restart/1,
    0x08 => &ZMachine.i0_ret_popped/1,
    0x09 => &ZMachine.i0_pop/1,
    0x0a => &ZMachine.i0_quit/1,
    0x0b => &ZMachine.i0_new_line/1,
    0x0c => &ZMachine.i0_show_status/1,
    0x0d => &ZMachine.i0_verify/1,
    0x0f => &ZMachine.i0_piracy/1,
    0x20 => &ZMachine.i1_jz/1,
    0x21 => &ZMachine.i1_get_sibling/1,
    0x22 => &ZMachine.i1_get_child/1,
    0x23 => &ZMachine.i1_get_parent/1,
    0x24 => &ZMachine.i1_get_prop_len/1,
    0x25 => &ZMachine.i1_inc/1,
    0x26 => &ZMachine.i1_dec/1,
    0x27 => &ZMachine.i1_print_addr/1,
    0x29 => &ZMachine.i1_remove_obj/1,
    0x2a => &ZMachine.i1_print_obj/1,
    0x2b => &ZMachine.i1_ret/1,
    0x2c => &ZMachine.i1_jump/1,
    0x2d => &ZMachine.i1_print_paddr/1,
    0x2e => &ZMachine.i1_load/1,
    0x2f => &ZMachine.i1_not/1,
    0x41 => &ZMachine.i2_je/1,
    0x42 => &ZMachine.i2_jl/1,
    0x43 => &ZMachine.i2_jg/1,
    0x44 => &ZMachine.i2_dec_chk/1,
    0x45 => &ZMachine.i2_inc_chk/1,
    0x46 => &ZMachine.i2_jin/1,
    0x47 => &ZMachine.i2_test/1,
    0x48 => &ZMachine.i2_or/1,
    0x49 => &ZMachine.i2_and/1,
    0x4a => &ZMachine.i2_test_attr/1,
    0x4b => &ZMachine.i2_set_attr/1,
    0x4c => &ZMachine.i2_clear_attr/1,
    0x4d => &ZMachine.i2_store/1,
    0x4e => &ZMachine.i2_insert_obj/1,
    0x4f => &ZMachine.i2_loadw/1,
    0x50 => &ZMachine.i2_loadb/1,
    0x51 => &ZMachine.i2_get_prop/1,
    0x52 => &ZMachine.i2_get_prop_addr/1,
    0x53 => &ZMachine.i2_get_next_prop/1,
    0x54 => &ZMachine.i2_add/1,
    0x55 => &ZMachine.i2_sub/1,
    0x56 => &ZMachine.i2_mul/1,
    0x57 => &ZMachine.i2_div/1,
    0x58 => &ZMachine.i2_mod/1,
    0x60 => &ZMachine.iV_call/1,
    0x61 => &ZMachine.iV_storew/1,
    0x62 => &ZMachine.iV_storeb/1,
    0x63 => &ZMachine.iV_put_prop/1,
    0x64 => &ZMachine.iV_sread/1,
    0x65 => &ZMachine.iV_print_char/1,
    0x66 => &ZMachine.iV_print_num/1,
    0x67 => &ZMachine.iV_random/1,
    # 0x67 => &ZMachine.iV_randomD/1,
    0x68 => &ZMachine.iV_push/1,
    0x69 => &ZMachine.iV_pull/1,
    0x6a => &ZMachine.iV_split_window/1,
    0x6b => &ZMachine.iV_set_window/1,
    0x73 => &ZMachine.iV_output_stream/1,
    0x74 => &ZMachine.iV_input_stream/1,
  }

  @state_running :running
  @state_quit :quit
  @state_waitInput :waitInput

  defstruct [
    :user_id,
    :memory,
    :curIp,
    :stack,
    :rand,
    :textBuffer,
    :parseBuffer,
    :screen,
    :state,
    :nextIp,
    :opCode,
    :operands,
    :operandTypes,
    :operandCount,
    :opCodeStore,
    :branchOff,
    :branchReversed,
    :printAddr,
    :debug,
  ]

  def new_game(user_id, image) do
    %ZMachine{
      user_id: user_id,
      memory: Memory.init(image),
      stack: Stack.new(),
      rand: 1,
      screen: Screen.new(),
      state: @state_running,
    }
    |> initFlags()
    |> initEntryPoint()
  end

  def restore_game(user_id, image, written, curIp, stack, rand, textBuffer, parseBuffer, screen) do
    %ZMachine{
      user_id: user_id,
      memory: Memory.init(image, written),
      curIp: curIp,
      stack: Stack.fromJson(stack),
      rand: rand,
      textBuffer: textBuffer,
      parseBuffer: parseBuffer,
      screen: Screen.new(screen),
      state: @state_waitInput,
    }
  end

  def location(z) do
    {_, addr} = getVariable(z, 0x10)
    Memory.getObjName(z.memory, addr)
  end

  def score(z) do
    {_, score} = getVariable(z, 0x11)
    score
  end

  def turns(z) do
    {_, turns} = getVariable(z, 0x12)
    turns
  end

  def initFlags(z) do
    b = Memory.getByte(z.memory, 1)
    memory = Memory.putByte(z.memory, 1, bor(b, 0x20))
    %ZMachine{z | memory: memory}
  end

  def initEntryPoint(z) do
    addr = Memory.getAddrEntryPoint(z.memory)
    %ZMachine{z | curIp: addr}
  end

  def getVariable(z, v) when v < 0x10 do
    {stack, value} = Stack.getVariable(z.stack, v)
    z = %ZMachine{z | stack: stack}
    {z, value}
  end

  def getVariable(z, v) do
    value = Memory.getGlobal(z.memory, v - 0x10)
    {z, value}
  end

  def setVariable(z, v, value) when v < 0x10 do
    stack = Stack.setVariable(z.stack, v, value)
    %ZMachine{z | stack: stack}
  end

  def setVariable(z, v, value) do
    memory = Memory.putGlobal(z.memory, v - 0x10, value)
    %ZMachine{z | memory: memory}
  end

  def decodeInstruction(z) do
    {z, addr} = decodeInstruction(z, band(Memory.getByte(z.memory, z.curIp), 0xc0))
    {z, addr, operands} = decodeOperands(z, addr, {})
    {addr, opCodeStore} = decodeStoreByte(z, addr)
    {addr, branchOff, branchReversed} = decodeBranch(z, addr)
    {addr, printAddr} = decodePrintAddr(z, addr)

    %ZMachine{z |
      operands: operands,
      opCodeStore: opCodeStore,
      branchOff: branchOff,
      branchReversed: branchReversed,
      printAddr: printAddr,
      nextIp: addr,
    }
  end

  def decodeInstruction(z, 0xc0) do # variable form insn
    opCode = Memory.getByte(z.memory, z.curIp)
    opCodeForm = if band(opCode, 0x20) == 0x20 do 3 else 2 end
    opCode = band(opCode, 0x1f)
    b1 = Memory.getByte(z.memory, z.curIp + 1)
    operandTypes = {
      band(bsr(b1, 6), 3),
      band(bsr(b1, 4), 3),
      band(bsr(b1, 2), 3),
      band(b1, 3),
    }
    operandCount = cond do
      elem(operandTypes, 0) == 3 -> 0
      elem(operandTypes, 1) == 3 -> 1
      elem(operandTypes, 2) == 3 -> 2
      elem(operandTypes, 3) == 3 -> 3
      true -> 4
    end
    opCode = bor(opCode, bsl(opCodeForm, 5))
    z = %ZMachine{z | opCode: opCode, operandTypes: operandTypes, operandCount: operandCount}
    {z, z.curIp + 2}
  end

  def decodeInstruction(z, 0x80) do # short form insn
    opCode = Memory.getByte(z.memory, z.curIp)
    opType = band(bsr(opCode, 4), 3)
    operandTypes = {opType}
    operandCount = if opType == 3 do 0 else 1 end
    opCode = bor(band(opCode, 0x0f), bsl(operandCount, 5))
    z = %ZMachine{z | opCode: opCode, operandTypes: operandTypes, operandCount: operandCount}
    {z, z.curIp + 1}
  end

  def decodeInstruction(z, _) do
    opCode = Memory.getByte(z.memory, z.curIp)
    operandTypes = {
      if band(opCode, 0x40) == 0x40 do 2 else 1 end,
      if band(opCode, 0x20) == 0x20 do 2 else 1 end,
    }
    opCode = bor(band(opCode, 0x1f), 0x40)
    z = %ZMachine{z | opCode: opCode, operandTypes: operandTypes, operandCount: 2}
    {z, z.curIp + 1}
  end

  def decodeOperands(z, addr, operands) do
    opNo = tuple_size(operands)
    if opNo < z.operandCount do
      opType = elem(z.operandTypes, opNo)
      {z, op, addr} = decodeOperand(z, addr, opType)
      decodeOperands(z, addr, Tuple.append(operands, op))
    else
      {z, addr, operands}
    end
  end

  def decodeOperand(z, addr, 0) do
    {z, Memory.getWord(z.memory, addr), addr + 2}
  end

  def decodeOperand(z, addr, 1) do
    {z, Memory.getByte(z.memory, addr), addr + 1}
  end

  def decodeOperand(z, addr, 2) do
    v = Memory.getByte(z.memory, addr)
    {z, value} = getVariable(z, v)
    {z, value, addr + 1}
  end

  def decodeStoreByte(z, addr) do
    if @hasStoreByte[z.opCode] do
      {addr + 1, Memory.getByte(z.memory, addr)}
    else
      {addr, nil}
    end
  end

  def decodeBranch(z, addr) do
    if @hasBranch[z.opCode] do
      b1 = Memory.getByte(z.memory, addr)
      branchOff = band(b1, 0x3f)
      branchReversed = band(b1, 0x80) == 0
      if band(b1, 0x40) != 0 do
        {addr + 1, branchOff, branchReversed}
      else
        b2 = Memory.getByte(z.memory, addr + 1)
        branchOff = bor(bsl(branchOff, 8), b2)
        if band(branchOff, 0x2000) != 0 do
          {addr + 2, bor(branchOff, 0xc000), branchReversed}
        else
          {addr + 2, branchOff, branchReversed}
        end
      end
    else
      {addr, nil, nil}
    end
  end

  def findPrintEnd(z, addr) do
    if band(Memory.getByte(z.memory, addr), 0x80) == 0 do
      findPrintEnd(z, addr + 2)
    else
      addr + 2
    end
  end

  def decodePrintAddr(z, addr) when z.opCode in [2, 3] do
    {findPrintEnd(z, addr), addr}
  end

  def decodePrintAddr(_z, addr) do
    {addr, nil}
  end

  def runLoop(z) when z.state == @state_running do
    z
    |> decodeInstruction()
    |> debug()
    |> execOp()
    |> advanceIp()
    |> runLoop()
  end

  def runLoop(z) do
    z
  end

  def processInput(z, input) when z.state == :waitInput do
    z = print(z, " " <> input <> "\r")
    z = case Memory.tokenize(z.memory, input, z.textBuffer, z.parseBuffer) do
      {:ok, memory} -> %ZMachine{z | memory: memory, state: @state_running}
      {:error, reason} -> print(z, reason)
    end
    runLoop(z)
  end

  def debug(z, ena \\ false) do
    if ena || z.debug do
      ot = case z.operandCount do
        0 -> {}
        1 -> {elem(z.operandTypes, 0)}
        2 -> {elem(z.operandTypes, 0), elem(z.operandTypes, 1)}
        3 -> {elem(z.operandTypes, 0), elem(z.operandTypes, 1), elem(z.operandTypes, 2)}
        4 -> {elem(z.operandTypes, 0), elem(z.operandTypes, 1), elem(z.operandTypes, 2), elem(z.operandTypes, 3)}
      end
      IO.puts("curIp: #{z.curIp}, nextIp: #{z.nextIp}, opCode: #{z.opCode}, opTy: #{inspect(ot)}, operands: #{inspect(z.operands)}, branch: #{makeSigned(z.branchOff)} #{z.branchReversed}, store: #{z.opCodeStore}")
    end
    z
  end

  def execOp(z) do
    @instructions[z.opCode].(z)
  end

  def advanceIp(z) do
    %ZMachine{z | curIp: z.nextIp}
  end

  def drawScreen(z) do
    z
  end

  def i0_rtrue(z) do
    doReturn(z, 1)
  end

  def i0_rfalse(z) do
    doReturn(z, 0)
  end

  def i0_print(z) do
    print(z, Memory.getZString(z.memory, z.printAddr))
  end

  def i0_print_ret(z) do
    z = print(z, Memory.getZString(z.memory, z.printAddr) <> "\r")
    doReturn(z, 1)
  end

  def i0_nop(z) do
    z
  end

  def i0_save(z) do
    GameCache.save_game(z, nil, nil)
    z
  end

  def i0_restore(z) do
    z
  end

  def i0_restart(z) do
    %ZMachine{
      user_id: z.user_id,
      memory: Memory.resetWrites(z.memory),
      screen: z.screen,
      stack: Stack.new(),
      state: @state_running,
      rand: 1,
    }
    |> initFlags()
    |> initEntryPoint()
  end

  def i0_ret_popped(z) do
    {z, value} = getVariable(z, 0)
    doReturn(z, value)
  end

  def i0_pop(z) do
    {z, _} = getVariable(z, 0)
    z
  end

  def i0_quit(z) do
    %ZMachine{z | state: @state_quit}
  end

  def i0_new_line(z) do
    print(z, "\r")
  end

  def i0_show_status(z) do
    # drawScreen()
    z
  end

  def i0_verify(z) do
    # todo: verify
    branch(z, true)
  end

  def i0_piracy(z) do
    branch(z, true)
  end

  def i1_jz(z) do
    branch(z, elem(z.operands, 0) == 0)
  end

  def i1_get_sibling(z) do
    s = Memory.getObjSibling(z.memory, elem(z.operands, 0))
    z = setVariable(z, z.opCodeStore, s)
    branch(z, s != 0)
  end

  def i1_get_child(z) do
    c = Memory.getObjChild(z.memory, elem(z.operands, 0))
    z = setVariable(z, z.opCodeStore, c)
    branch(z, c != 0)
  end

  def i1_get_parent(z) do
    p = Memory.getObjParent(z.memory, elem(z.operands, 0))
    setVariable(z, z.opCodeStore, p)
  end

  def i1_get_prop_len(z) do
    l = Memory.getPropLen(z.memory, elem(z.operands, 0))
    setVariable(z, z.opCodeStore, l)
  end

  def i1_inc(z) do
    varNo = elem(z.operands, 0)
    {z, value} = getVariable(z, varNo)
    value = band(value + 1, 0xffff)
    setVariable(z, varNo, value)
  end

  def i1_dec(z) do
    varNo = elem(z.operands, 0)
    {z, value} = getVariable(z, varNo)
    value = band(value - 1, 0xffff)
    setVariable(z, varNo, value)
  end

  def i1_print_addr(z) do
    print(z, Memory.getZString(z.memory, elem(z.operands, 0)))
  end

  def i1_remove_obj(z) do
    memory = Memory.removeObj(z.memory, elem(z.operands, 0))
    %ZMachine{z | memory: memory}
  end

  def i1_print_obj(z) do
    str = Memory.getObjName(z.memory, elem(z.operands, 0))
    print(z, str)
  end

  def i1_ret(z) do
    doReturn(z, elem(z.operands, 0))
  end

  def i1_jump(z) do
    nextIp = z.nextIp + makeSigned(elem(z.operands, 0)) - 2
    %ZMachine{z | nextIp: nextIp}
  end

  def i1_print_paddr(z) do
    print(z, Memory.getZString(z.memory, elem(z.operands, 0) * 2))
  end

  def i1_load(z) do
    {z, value} = getVariable(z, elem(z.operands, 0))
    setVariable(z, z.opCodeStore, value)
  end

  def i1_not(z) do
    setVariable(z, z.opCodeStore, band(bnot(elem(z.operands, 0)), 0xffff))
  end

  def isEq(z, o) when o == z.operandCount do
    false
  end

  def isEq(z, o) when elem(z.operands, o) == elem(z.operands, 0) do
    true
  end

  def isEq(z, o) do
    isEq(z, o + 1)
  end

  def i2_je(z) do
    branch(z, isEq(z, 1))
  end

  def i2_jl(z) do
    branch(z, makeSigned(elem(z.operands, 0)) < makeSigned(elem(z.operands, 1)))
  end

  def i2_jg(z) do
    branch(z, makeSigned(elem(z.operands, 0)) > makeSigned(elem(z.operands, 1)))
  end

  def i2_dec_chk(z) do
    {z, val} = getVariable(z, elem(z.operands, 0))
    val = band(val - 1, 0xffff)
    z = setVariable(z, elem(z.operands, 0), val)
    branch(z, makeSigned(val) < makeSigned(elem(z.operands, 1)))
  end

  def i2_inc_chk(z) do
    {z, val} = getVariable(z, elem(z.operands, 0))
    val = band(val + 1, 0xffff)
    z = setVariable(z, elem(z.operands, 0), val)
    branch(z, makeSigned(val) > makeSigned(elem(z.operands, 1)))
  end

  def i2_jin(z) do
    branch(z, Memory.getObjParent(z.memory, elem(z.operands, 0)) == elem(z.operands, 1))
  end

  def i2_test(z) do
    branch(z, band(elem(z.operands, 0), elem(z.operands, 1)) == elem(z.operands, 1))
  end

  def i2_or(z) do
    setVariable(z, z.opCodeStore, bor(elem(z.operands, 0), elem(z.operands, 1)))
  end

  def i2_and(z) do
    setVariable(z, z.opCodeStore, band(elem(z.operands, 0), elem(z.operands, 1)))
  end

  def i2_test_attr(z) do
    branch(z, Memory.getObjAttrib(z.memory, elem(z.operands, 0), elem(z.operands, 1)))
  end

  def i2_set_attr(z) do
    memory = Memory.setObjAttrib(z.memory, elem(z.operands, 0), elem(z.operands, 1), true)
    %ZMachine{z | memory: memory}
  end

  def i2_clear_attr(z) do
    memory = Memory.setObjAttrib(z.memory, elem(z.operands, 0), elem(z.operands, 1), false)
    %ZMachine{z | memory: memory}
  end

  def i2_store(z) do
    setVariable(z, elem(z.operands, 0), elem(z.operands, 1))
  end

  def i2_insert_obj(z) do
    memory = Memory.insertObj(z.memory, elem(z.operands, 0), elem(z.operands, 1))
    %ZMachine{z | memory: memory}
  end

  def i2_loadw(z) do
    w = Memory.getWord(z.memory, elem(z.operands, 0) + elem(z.operands, 1) * 2)
    setVariable(z, z.opCodeStore, w)
  end

  def i2_loadb(z) do
    b = Memory.getByte(z.memory, elem(z.operands, 0) + elem(z.operands, 1))
    setVariable(z, z.opCodeStore, b)
  end

  def i2_get_prop(z) do
    p = Memory.getProp(z.memory, elem(z.operands, 0), elem(z.operands, 1))
    setVariable(z, z.opCodeStore, p);
  end

  def i2_get_prop_addr(z) do
    a = Memory.getPropAddr(z.memory, elem(z.operands, 0), elem(z.operands, 1))
    setVariable(z, z.opCodeStore, a)
  end

  def i2_get_next_prop(z) do
    p = Memory.getPropNext(z.memory, elem(z.operands, 0), elem(z.operands, 1))
    setVariable(z, z.opCodeStore, p)
  end

  def i2_add(z) do
    setVariable(z, z.opCodeStore, band(elem(z.operands, 0) + elem(z.operands, 1), 0xffff))
  end

  def i2_sub(z) do
    setVariable(z, z.opCodeStore, band(elem(z.operands, 0) - elem(z.operands, 1), 0xffff))
  end

  def i2_mul(z) do
    setVariable(z, z.opCodeStore, band(elem(z.operands, 0) * elem(z.operands, 1), 0xffff))
  end

  def i2_div(z) do
    setVariable(z, z.opCodeStore, band(div(makeSigned(elem(z.operands, 0)), makeSigned(elem(z.operands, 1))), 0xffff))
  end

  def i2_mod(z) do
    setVariable(z, z.opCodeStore, band(rem(makeSigned(elem(z.operands, 0)), makeSigned(elem(z.operands, 1))), 0xffff))
  end

  def iV_call(z) do
    unless z.operandCount > 0 do
      raise "bad operandCount for call"
    end
    addr = elem(z.operands, 0) * 2
    if addr != 0 do
      nLocs = Memory.getByte(z.memory, addr)
      frame = StackFrame.new(z.nextIp, z.opCodeStore)
      frame = initCallFrame(z, frame, nLocs, 0)
      z = %ZMachine{z |
        nextIp: addr + 1 + nLocs * 2,
        stack: [frame | z.stack],
      }
      z
    else
      setVariable(z, z.opCodeStore, 0)
    end
  end

  def initCallFrame(_z, frame, nLocs, nLocs) do
    frame
  end

  def initCallFrame(z, frame, nLocs, v) when v + 1 < z.operandCount do
    value = elem(z.operands, v + 1)
    frame = StackFrame.putLocal(frame, v + 1, value)
    initCallFrame(z, frame, nLocs, v + 1)
  end

  def initCallFrame(z, frame, nLocs, v) do
    addr = (elem(z.operands, 0) + v) * 2 + 1
    value = Memory.getWord(z.memory, addr)
    frame = StackFrame.putLocal(frame, v + 1, value)
    initCallFrame(z, frame, nLocs, v + 1)
  end

  def iV_storew(z) do
    memory = Memory.putWord(z.memory, elem(z.operands, 0) + elem(z.operands, 1) * 2, elem(z.operands, 2))
    %ZMachine{z | memory: memory}
  end

  def iV_storeb(z) do
    memory = Memory.putByte(z.memory, elem(z.operands, 0) + elem(z.operands, 1), elem(z.operands, 2))
    %ZMachine{z | memory: memory}
  end

  def iV_put_prop(z) do
    memory = Memory.setProp(z.memory, elem(z.operands, 0), elem(z.operands, 1), elem(z.operands, 2))
    %ZMachine{z | memory: memory}
  end

  def iV_sread(z) do
    %ZMachine{z |
      state: @state_waitInput,
      textBuffer: elem(z.operands, 0),
      parseBuffer: elem(z.operands, 1),
    }
  end

  def iV_print_char(z) do
    print(z, <<elem(z.operands, 0)>>)
  end

  def iV_print_num(z) do
    str = to_string(makeSigned(elem(z.operands, 0)))
    print(z, str)
  end

  def iV_random(z) do
    range = makeSigned(elem(z.operands, 0))
    value = cond do
      range > 0 -> :rand.uniform(range)
      range < 0 ->
        :rand.seed(:exsplus, -range)
        0
      range == 0 ->
        :rand.seed(:exsplus)
        0
    end
    setVariable(z, z.opCodeStore, value)
  end

  def iV_randomD(z) do
    range = makeSigned(elem(z.operands, 0))
    if range > 0 do
      value = rem(z.rand, range) + 1
      z = setVariable(z, z.opCodeStore, value)
      %ZMachine{z | rand: z.rand + 1}
    else
      z = setVariable(z, z.opCodeStore, 0)
      %ZMachine{z | rand: -range}
    end
  end

  def iV_push(z) do
    setVariable(z, 0, elem(z.operands, 0))
  end

  def iV_pull(z) do
    {z, value} = getVariable(z, 0)
    setVariable(z, elem(z.operands, 0), value);
  end

  def iV_split_window(z) do
    # splitWindow(operands[0]);
    z
  end

  def iV_set_window(z) do
    # setWindow(operands[0]);
    z
  end

  def iV_output_stream(z) do
    # setOutputStream(operands[0])
    z
  end

  def iV_input_stream(z) do
    # setInputStream(operands[0])
    z
  end

  # when take == reversed we _do_not_ take the branch
  def branch(z, take) when take == z.branchReversed do
    z
  end

  def branch(z, _take) when z.branchOff in [0, 1] do
    doReturn(z, z.branchOff)
  end

  def branch(z, _take) do
    %ZMachine{z | nextIp: z.nextIp - 2 + makeSigned(z.branchOff)}
  end

  def doReturn(z, value) do
    [top | stack] = z.stack
    z = %ZMachine{z | stack: stack, nextIp: top.nextIp}
    setVariable(z, top.storeReturn, value)
  end

  def makeSigned(nil) do
    nil
  end

  def makeSigned(v) when v >= 0x8000 do
    v - 0x10000
  end

  def makeSigned(v) do
    v
  end

  def print(z, s) do
    screen = Screen.print(z.screen, s)
    %ZMachine{z | screen: screen}
  end
end
