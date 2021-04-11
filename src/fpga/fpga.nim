import register
import read_config
import strformat
import tables

var initialized = false 

var config: RegisterConfig
var config_path = "regs.cfg"

proc initialize() = 
  if not initialized:
    try:
        config = read_config(config_path)
        for reg in config.registers:
          add_register(reg)

    except Exception:
      echo "Config Exception: " & getCurrentExceptionMsg()
      raise

    initialized = true

proc register_write_handler*(control: uint32, value: uint32) =
  initialize()
  if registers.contains(control):
    for reg in registers[control]:
      if reg.direction == WRITE:
        reg.set(value)
  else:
    if config.show_unknown:
      echo &"WRITE | {value:08x} | 0x{control:08x}"

proc register_read_handler*(indicator: uint32, value: ptr uint32) =
  initialize()
  if registers.contains(indicator):
    for reg in registers[indicator]:
      if reg.direction == READ:
        reg.set(value[])
  else:
    if config.show_unknown:
      echo &"READ  | {value[]:08x} | 0x{indicator:08x}"