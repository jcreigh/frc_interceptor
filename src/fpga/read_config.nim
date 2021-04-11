import register
import parsecfg, streams, strutils

type
  RegisterConfig* = object
    registers*: seq[Register]
    show_unknown*: bool

proc newRegisterConfig(): RegisterConfig =
  return RegisterConfig(show_unknown:false)


proc read_config*(filename: string): RegisterConfig =
  var f = newFileStream(filename, fmRead)
  var reg: Register

  var config = newRegisterConfig()

  var res: seq[Register]
  if f != nil:
    var p: CfgParser
    open(p, f, filename)
    while true:
      var e = next(p)
      case e.kind
      of cfgEof: 
        if reg.name != "":
          res.add reg
        break
      of cfgSectionStart:
        if reg.name == "":
          reg = newRegister(e.section)
        else:
          res.add reg
          reg = Register()
          reg = newRegister(e.section)
      of cfgKeyValuePair:
        let key = e.key
        let val = e.value
        if key.cmpIgnoreCase("type") == 0:
          if val.cmpIgnoreCase("Indicator") == 0:
            reg.direction = READ
          elif val.cmpIgnoreCase("Control") == 0:
            reg.direction = WRITE
          else:
            raise newException(ValueError, p.errorstr("Invalid type"))
        elif key.cmpIgnoreCase("offset") == 0:
          try:
            reg.offset = fromHex[uint32](val)
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        elif key.cmpIgnoreCase("reg_size") == 0:
          try:
            reg.read_loc.size = val.parseInt().uint32
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        elif key.cmpIgnoreCase("reg_offset") == 0:
          try:
            reg.read_loc.offset = val.parseInt().uint32
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        elif key.cmpIgnoreCase("shm_offset") == 0:
          try:
            reg.shm_offset = val.parseInt().uint32
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        elif key.cmpIgnoreCase("shm_path") == 0:
          reg.shm_path = val
        elif key.cmpIgnoreCase("active") == 0:
          try:
            reg.active = val.parseBool()
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        elif key.cmpIgnoreCase("show") == 0:
          try:
            reg.show = val.parseBool()
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        else:
          raise newException(ValueError, p.errorStr("Invalid key"))
      of cfgOption:
        if e.key.cmpIgnoreCase("show_unknown") == 0:
          try:
            config.show_unknown = e.value.parseBool()
          except ValueError:
            raise newException(ValueError, p.errorstr(getCurrentExceptionMsg()))
        else:
          raise newException(ValueError, p.errorStr("Invalid option"))
      of cfgError:
        raise newException(ValueError, e.msg)
    close(p)
  else:
    raise newException(OSError, "Failed to open: " & filename)

  config.registers = res
  return config