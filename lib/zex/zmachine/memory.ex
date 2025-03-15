defmodule Zex.ZMachine.Memory do
  alias Zex.ZMachine.Memory
  alias Zex.ZMachine.StringEncoding
  import Bitwise, only: [band: 2, bor: 2, bnot: 1, bsr: 2]

  defstruct [:image, :written, :wordSepList]

  def init(image, written \\ %{}) do
    %Memory{
      image: image,
      written: written
    }
    |> buildWordSeparators()
  end

  def resetWrites(memory) do
    %Memory{memory | written: %{}}
  end

  #def fromJson(memory, decoded) do
  #  written = withIntKeys(decoded["memory"])
  #  memory = %Memory{memory | written: written}
  #  {:ok, memory}
  #end

  #def withIntKeys(map) when is_map(map) do
  #  remap = fn {key, value}, map ->
  #    {key, ""} = Integer.parse(key)
  #    Map.put(map, key, value)
  #  end
  #  Enum.reduce(map, %{}, remap)
  #end

  def buildWordSeparators(memory) do
    addr = getAddrDict(memory)
    sepList = buildSepList(memory, addr + 1, getByte(memory, addr), [" "])
    %Memory{memory | wordSepList: sepList}
  end

  def buildSepList(_memory, _addr, 0, list) do
    list
  end

  def buildSepList(memory, addr, count, list) do
    sep = <<getByte(memory, addr)>>
    buildSepList(memory, addr + 1, count - 1, [sep | list])
  end

  def getByte(memory, addr) do
    case Map.get(memory.written, addr) do
      nil ->
        <<v>> = binary_part(memory.image, addr, 1)
        v
      v -> v
    end
  end

  def getWord(memory, addr) do
    getByte(memory, addr) * 256 + getByte(memory, addr + 1)
  end

  def getDword(memory, addr) do
    <<getByte(memory, addr), getByte(memory, addr + 1), getByte(memory, addr + 2), getByte(memory, addr + 3)>>
  end

  def putByte(memory, addr, value) do
    if value == binary_part(memory.image, addr, 1) do
      %Memory{memory | written: Map.delete(memory.written, addr)}
    else
      %Memory{memory | written: Map.put(memory.written, addr, value)}
    end
  end

  def putWord(memory, addr, value) do
    memory
    |> putByte(addr, div(value, 256))
    |> putByte(addr+1, rem(value, 256))
  end

  def putString(memory, _addr, <<>>) do
    memory
  end

  def putString(memory, addr, str) do
    <<c, rest::binary>> = str
    memory
    |> putByte(addr, c)
    |> putString(addr + 1, rest)
  end

  def getAddrAbbrevTbl(memory) do
    getWord(memory, 0x18)
  end

  def getAddrDict(memory) do
    getWord(memory, 0x08)
  end

  def getAddrEntryPoint(memory) do
    getWord(memory, 0x06)
  end

  def getAddrGlobalTbl(memory) do
    getWord(memory, 0x0c)
  end

  def getAddrHighMem(memory) do
    getWord(memory, 0x04)
  end

  def getAddrObjTbl(memory) do
    getWord(memory, 0x0a) + 53
  end

  def getAddrObj(memory, objNo) do
    getAddrObjTbl(memory) + objNo * 9
  end

  def getAddrStaticMem(memory) do
    getWord(memory, 0x0e)
  end

  def getGlobal(memory, v) do
    getWord(memory, getAddrGlobalTbl(memory) + v * 2)
  end

  def putGlobal(memory, v, value) do
    putWord(memory, getAddrGlobalTbl(memory) + v * 2, value)
  end

  def getObjAttrib(memory, objNo, attrNo) do
    addr = getAddrObj(memory, objNo) + div(attrNo, 8)
    by = getByte(memory, addr)
    b = band(by, bsr(0x80, rem(attrNo, 8)))
    b != 0
  end

  def setObjAttrib(memory, objNo, attrNo, set) do
    addr = getAddrObj(memory, objNo) + bsr(attrNo, 3)
    bit = bsr(0x80, band(attrNo, 7))
    value = getByte(memory, addr)
    value = if set do
      bor(value, bit)
    else
      band(value, bnot(bit))
    end
    putByte(memory, addr, value)
  end

  def getObjParent(memory, objNo) do
    getByte(memory, getAddrObj(memory, objNo) + 4)
  end

  def setObjParent(memory, objNo, parent) do
    putByte(memory, getAddrObj(memory, objNo) + 4, parent)
  end

  def getObjSibling(memory, objNo) do
    getByte(memory, getAddrObj(memory, objNo) + 5)
  end

  def setObjSibling(memory, objNo, sibling) do
    putByte(memory, getAddrObj(memory, objNo) + 5, sibling)
  end

  def getObjChild(memory, objNo) do
    c = getByte(memory, getAddrObj(memory, objNo) + 6)
    c
  end

  def setObjChild(memory, objNo, child) do
    putByte(memory, getAddrObj(memory, objNo) + 6, child)
  end

  def getObjName(memory, objNo) do
    getZString(memory, getObjPropAddr(memory, objNo) + 1)
  end

  def getObjPropAddr(memory, objNo) do
    getWord(memory, getAddrObj(memory, objNo) + 7)
  end

  def getProp(memory, objNo, propNo) do
    addr = getPropAddr(memory, objNo, propNo);
    if (addr == 0) do
      unless propNo > 0 do
        raise "getProp: invalid propNo"
      end
      getWord(memory, getAddrObjTbl(memory) - 55 + propNo * 2)
    else
      if getPropLen(memory, addr) == 1 do
        getByte(memory, addr)
      else
        getWord(memory, addr)
      end
    end
  end

  def setProp(memory, objNo, propNo, value) do
    addr = getPropAddr(memory, objNo, propNo)
    if addr == 0 do
      raise "Bad property"
    end

    if getPropLen(memory, addr) == 1 do
      putByte(memory, addr, value)
    else
      putWord(memory, addr, value)
    end
  end

  def getPropAddr(memory, objNo, propNo) do
    addr = getObjPropAddr(memory, objNo)
    textLen = getByte(memory, addr)
    findPropAddr(memory, addr + textLen * 2 + 1, propNo)
  end

  def findPropAddr(memory, addr, propNo) do
    size = getByte(memory, addr)
    cond do
      size == 0 -> 0
      band(size, 0x1f) == propNo -> addr + 1
      true -> findPropAddr(memory, addr + band(bsr(size, 5), 0x07) + 2, propNo)
    end
  end

  def getPropLen(memory, addr) do
    band(bsr(getByte(memory, addr - 1), 5), 7) + 1
  end

  def getPropNext(memory, objNo, 0) do
    addr = getObjPropAddr(memory, objNo)
    textLen = getByte(memory, addr)
    band(getByte(memory, addr + textLen * 2 + 1), 0x1f)
  end

  def getPropNext(memory, objNo, propNo) do
    addr = getPropAddr(memory, objNo, propNo)
    if addr == 0 do
      0
    else
      band(getByte(memory, addr + getPropLen(memory, addr)), 0x1f)
    end
  end

  def insertObj(memory, objNo, parent) do
    memory
    |> removeObj(objNo)
    |> setObjSibling(objNo, getObjChild(memory, parent))
    |> setObjChild(parent, objNo)
    |> setObjParent(objNo, parent)
  end

  def removeObj(memory, objNo) do
    parent = getObjParent(memory, objNo)
    removeObjFromParent(memory, objNo, parent)
  end

  def removeObjFromParent(memory, _objNo, 0) do
    memory
  end

  def removeObjFromParent(memory, objNo, parent) do
    nextSibling = getObjSibling(memory, objNo)
    firstSibling = getObjChild(memory, parent)
    memory
    |> setObjParent(objNo, 0)
    |> setObjSibling(objNo, 0)
    |> removeChild(objNo, parent, firstSibling, nextSibling)
  end

  def removeChild(memory, objNo, parent, objNo, nextSibling) do
    setObjChild(memory, parent, nextSibling)
  end

  def removeChild(memory, objNo, _parent, firstSibling, nextSibling) do
    prevSibling = findPrevSibling(memory, objNo, firstSibling)
    setObjSibling(memory, prevSibling, nextSibling)
  end

  def findPrevSibling(memory, objNo, prevSibling) do
    case getObjSibling(memory, prevSibling) do
      0 -> raise "Bad object"
      ^objNo -> prevSibling
      nextSibling -> findPrevSibling(memory, objNo, nextSibling)
    end
  end

  def getString(memory, addr, len \\ -1, str \\ "") do
    c = getByte(memory, addr)
    if c == 0 || len == 0 do
      str
    else
      getString(memory, addr + 1, len - 1, str <> <<c>>)
    end
  end

  def getZString(memory, addr) do
    StringEncoding.getZstring(memory, addr)
  end

  def tokenize(memory, input, textAddr, parseAddr) do
    input = tokenizeNormalizeInput(input)
    with {:ok, memory} <- tokenizeText(memory, input, textAddr),
         {:ok, memory} <- parseText(memory, input, parseAddr)
    do
      {:ok, memory}
    else
      err -> err
    end
  end

  def tokenizeNormalizeInput(input) do
    input = String.replace(input, "?", "")
    input = String.trim(input)
    input = singularizeSpaces(input)
    String.downcase(input)
  end

  def singularizeSpaces(input) do
    case :binary.match(input, "  ") do
      {off, _} -> singularizeSpaces(binary_part(input, 0, off + 1) <> binary_part(input, off + 2, String.length(input) - off - 2))
      :nomatch -> input
    end
  end

  def tokenizeText(memory, "", textAddr) do
    memory = putByte(memory, textAddr + 1, 0)
    {:ok, memory}
  end

  def tokenizeText(memory, input, textAddr) do
    textLimit = getByte(memory, textAddr)
    textLen = String.length(input)
    if textLen + 1 > textLimit do
      {:error, "Input is too long"}
    else
      tokenizePutText(memory, input, textAddr + 1, 0, textLen)
    end
  end

  def tokenizePutText(memory, _input, addr, _index, 0) do
    memory = putByte(memory, addr, 0)
    {:ok, memory}
  end

  def tokenizePutText(memory, input, addr, index, count) do
    <<c>> = String.at(input, index)
    memory = putByte(memory, addr, c)
    tokenizePutText(memory, input, addr + 1, index + 1, count - 1)
  end

  def parseText(memory, "", parseAddr) do
    memory = putByte(memory, parseAddr + 1, 0)
    {:ok, memory}
  end

  def parseText(memory, input, parseAddr) do
    wordLimit = getByte(memory, parseAddr)
    with {:ok, memory, wordCount} <- parseWords(memory, input, parseAddr + 2, 0, 0, wordLimit)
    do
      memory = putByte(memory, parseAddr + 1, wordCount)
      {:ok, memory}
    else
      err -> err
    end
  end

  def parseWords(_memory, _input, _wordAddr, _wordOff, _wordCount, 0) do
    {:error, "Too many words"}
  end

  def parseWords(memory, input, wordAddr, wordOff, wordCount, wordLimit) do
    {wordOff, wordEnd} = findEndOfWord(memory, input, wordOff)
    parseWord(memory, input, wordAddr, wordOff, wordEnd, wordCount, wordLimit)
  end

  def parseWord(memory, _input, _wordAddr, wordOff, wordOff, wordCount, _wordLimit) do
    {:ok, memory, wordCount}
  end

  def parseWord(memory, input, wordAddr, wordOff, wordEnd, wordCount, wordLimit) do
    word = binary_part(input, wordOff, wordEnd - wordOff)
    token = StringEncoding.encodeWord(word)
    addrDictEntry = findInDict(memory, token)
    memory
    |> putWord(wordAddr, addrDictEntry)
    |> putByte(wordAddr + 2, wordEnd - wordOff)
    |> putByte(wordAddr + 3, wordOff + 1)
    |> parseWords(input, wordAddr + 4, wordEnd, wordCount + 1, wordLimit - 1)
  end

  def skipLeadingSpace(input, off) do
    len = String.length(input)
    if off < len && String.at(input, off) == " " do
      skipLeadingSpace(input, off + 1)
    else
      off
    end
  end

  def findEndOfWord(memory, input, wordOff) do
    wordOff = skipLeadingSpace(input, wordOff)
    rest = binary_part(input, wordOff, String.length(input) - wordOff)
    case :binary.match(rest, memory.wordSepList) do
      :nomatch -> {wordOff, String.length(input)}
      {0, _} -> {wordOff, wordOff + 1}
      {off, _} -> {wordOff, wordOff + off}
    end
  end

  def findInDict(memory, token) do
    addrDict = getAddrDict(memory)
    sepCount = getByte(memory, addrDict)
    entrySize = getByte(memory, addrDict + sepCount + 1)
    wordCount = getWord(memory, addrDict + sepCount + 2)
    addrWords = addrDict + sepCount + 4

    wordNo = findInDict(memory, token, addrWords, entrySize, 0, wordCount - 1)
    if wordNo < 0 do
      0
    else
      addrWords + wordNo * entrySize
    end
  end

  def findInDict(_memory, _word, _addrWords, _entrySize, lo, hi) when lo > hi do
    -1
  end

  def findInDict(memory, token, addrWords, entrySize, lo, hi) do
    e = div(lo + hi, 2)
    dictToken = getDword(memory, addrWords + e * entrySize)
    cond do
      dictToken == token -> e
      dictToken < token -> findInDict(memory, token, addrWords, entrySize, e + 1, hi)
      dictToken > token -> findInDict(memory, token, addrWords, entrySize, lo, e - 1)
    end
  end
end
