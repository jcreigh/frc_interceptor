import injector
import fpga/fpga


proc NiFpgaDll_WriteU32(session: uint32, control: uint32, value: uint32): uint32 {.sym_inject.} =
  register_write_handler(control, value)
  return real_NiFpgaDll_WriteU32(session, control, value)

proc NiFpgaDll_ReadU32(session: uint32, indicator: uint32, value: ptr uint32): uint32 {.sym_inject.} =
  var tmp = real_NiFpgaDll_ReadU32(session, indicator, value)
  register_read_handler(indicator, value)
  return tmp
