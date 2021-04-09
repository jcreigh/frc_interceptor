import injector
import strutils
import posix

let LED_offset: uint32 = 0x18010

var shm_fd: cint = -1
var led_value: ptr uint32

proc configure_shm() =
  if shm_fd >= 0:
    return

  while true:
    shm_fd = shm_open("/netcomm_leds", O_CREAT or O_EXCL or O_RDWR, cast[Mode](S_IRUSR or S_IWUSR or S_IROTH))
    if shm_fd >= 0:
      break

    if errno == EEXIST:
      echo "shmem: netcomm_leds exists: "
      if shm_unlink("/netcomm_leds") >= 0:
        echo " deleted"
      else:
        echo " failed to delete"
        quit(1)
    else:
      echo "err: ", errno
      quit(1)

  discard ftruncate(shm_fd, 4)

  led_value = cast[ptr uint32](mmap(nil, 4, PROT_READ or PROT_WRITE, MAP_SHARED, shm_fd, 0))

proc NiFpgaDll_WriteU32(session: uint32, control: uint32, value: uint32): uint32 {.sym_inject.} =
  #echo "Write ", control.toHex, " ", value
  configure_shm()

  if control == LED_OFFSET:
    led_value[] = value

  return real_NiFpgaDll_WriteU32(session, control, value)

#proc NiFpgaDll_ReadU32(session: uint32, indicator: uint32, value: ptr uint32): uint32 {.sym_inject.} =
#  echo "Read  ", indicator.toHex, " ", value
#  return real_NiFpgaDll_ReadU32(session, indicator, value)
