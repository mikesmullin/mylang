defType Unit Bit b
defType Unit Byte b
1 Byte setUnitEquivalentOf 8 Bit

defId Bit a setValue 1b
defId Bit b setValue 2
defId c setValue 3b
defId d setValue 0x04 # compiler error; must specify a type
