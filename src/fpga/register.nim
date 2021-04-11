import tables
import math
import os
import posix
import strutils
import strformat

type
  Direction* = enum
    UNKNOWN, READ, WRITE

  BitLocation* = object
    size*: uint32
    offset*: uint32

  Register* = object
    name*: string
    offset*: uint32
    read_loc*: BitLocation
    write_loc*: BitLocation
    shm_path*: string
    shm_offset*: uint32
    direction*: Direction
    active*: bool
    show*: bool

proc newBitLocation*(size: uint32 = 0, offset: uint32=0): BitLocation =
  return BitLocation(size: size, offset: offset)

proc newBitLocation*(bitloc: array[2, int]): BitLocation =
  return newBitLocation(bitloc[0].uint32, bitloc[1].uint32)

converter toBitLocation*(bitloc: array[2, int]): BitLocation = newBitLocation(bitLoc)
converter toBitLocation*(offset: int): BitLocation = newBitLocation(offset.uint32)


# TODO: Make this output format less wonky

proc toStr*(bitloc: BitLocation, short:bool=false): string =
  if short and bitloc.offset == 0:
    &"[size: {bitloc.size}]"
  else:
    &"[size: {bitloc.size}, offset: {bitloc.offset}]"

converter toStr*(bitloc: BitLocation): string = $bitloc

proc toStr*(reg: Register, short:bool=false): string =
  var buf: string
  buf = &"[name: {reg.name}, offset: {reg.offset:08x}, direction: {reg.direction}, "
  buf &= &"read_loc: {reg.read_loc.toStr(short)}"
  if short:
    if reg.write_loc.size != 0:
      buf &= &", write_loc: {reg.write_loc.toStr(short)}"
    if reg.shm_path.len != 0:
      buf &= &", shm_path: {reg.shm_path}"
    if reg.shm_offset != 0:
      buf &= &", shm_offset: {reg.shm_offset}"
  buf &= "]"
  buf

converter toStr*(reg: Register): string = $reg



proc newRegister*(name: string, offset: int, direction: Direction, read_loc: BitLocation,
                 write_loc: BitLocation=0, shm_path: string="", shm_offset: uint32=0,
                 show: bool=false, active: bool=true): Register =
 return Register(name:name, offset:offset.uint32, direction:direction, read_loc:read_loc,
                 write_loc:write_loc, shm_path:shm_path, shm_offset:shm_offset,
                 show:show, active:active)

proc newRegister*(name: string): Register = return newRegister(name, 0, UNKNOWN, 0)

var registers* {.global.} = initTable[uint32, seq[Register]]()
var register_shm {.global.} = initTable[string, ptr uint32]()

proc create_shm(reg: var Register) =
  if register_shm.contains(reg.name):
    return

  var shm_fd: cint = -1
  let shm_path = "/frc_netcomm." & 
                 (if reg.shm_path.len == 0: reg.name
                 else:                      reg.shm_path)


  #echo &"shm_open: {reg.name} @ {shm_path}:{reg.shm_offset}"
  shm_fd = shm_open(shm_path, O_CREAT or O_RDWR, cast[Mode](S_IRUSR or S_IWUSR or S_IROTH))
  if shm_fd < 0:
    raise newException(OSError, &"shm_open error: {errno:-3}  {strerror(errno)}")

  let size_bytes = ((reg.read_loc.size - 1) div 8 + 1)

  let cur_size = getFileInfo(shm_fd).size.uint32 
  let required_size = size_bytes + reg.shm_offset

  if cur_size < required_size:
    let ret = ftruncate(shm_fd, Off(required_size))
    if ret < 0:
      raise newException(OSError, &"ftruncate error: {errno:-3}  {strerror(errno)}")

  let loc: pointer = mmap(nil, size_bytes.int, PROT_READ or PROT_WRITE, MAP_SHARED, shm_fd, Off(0))
  if loc == MAP_FAILED:
    raise newException(OSError, &"mmap error: {errno:-3}  {strerror(errno)}")

  let actual_loc = cast[ptr uint32](cast[uint32](loc) + reg.shm_offset)
  register_shm[reg.name] = actual_loc

proc set*(reg: Register, value: uint32) =
  if not reg.active:
    return
  # shrug, mask out region where value goes and then OR it in
  # currently useless cause we don't actually use write_loc right now
  let data = cast[ptr uint32](register_shm[reg.name])
  let m: uint32 = (value shr reg.read_loc.offset) and ((1 shl reg.read_loc.size) - 1).uint32
  let v: uint32 = m and not ((nextPowerOfTwo(m.int).uint32 - 1) shl reg.write_loc.offset)
  let z: uint32 = (m shl reg.write_loc.offset) or v
  if reg.show:
    echo &"{reg.direction:-5} | {z:08x} | {reg.toStr(true)}"
  data[] = z

proc add_register*(reg: Register) =
  if registers.contains(reg.offset) == false:
    registers[reg.offset] = newSeq[Register]()
  registers[reg.offset].add reg
  if reg.active:
    create_shm(registers[reg.offset][registers[reg.offset].len - 1])
