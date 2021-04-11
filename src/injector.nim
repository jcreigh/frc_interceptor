import tables

# Global holding all the handlers
var injector_handlers* {.global.} = initTable[string, pointer]()

# Fix const char* warnings with C interop
{.emit: """/*TYPESECTION*/ typedef const char* ConstCStr;""".}
type constCStr* {.importc: "ConstCStr", nodecl.} = cstring

type dlsym_type = proc(handle: pointer, name: cstring): pointer {.stdcall.}
var real_dlsym*: dlsym_type

var RTLD_NEXT {.header:"dlfcn.h".}: cint

# glibc's dlsym in order to look up real function addresses
{.emit: """extern void* _dl_sym(void*, char const*, void*);""".}
proc glibc_dl_sym(handle: pointer, name: constCStr, who: pointer): pointer {.header:"dlfcn.h", importc:"_dl_sym", stdcall.}


include injector_macro


proc dlsym*(handle: pointer, name: constCStr): pointer {.exportc, dynlib, cdecl.} = 
  let cname = cast[cstring](name)
  if real_dlsym == nil:
    real_dlsym = cast[dlsym_type](glibc_dl_sym(cast[pointer](RTLD_NEXT), "dlsym", cast[pointer](dlsym)))
    when defined(arm):  # ???
      real_dlsym = cast[dlsym_type](glibc_dl_sym(cast[pointer](RTLD_NEXT), "dlsym", cast[pointer](real_dlsym)))
    if real_dlsym == nil:
      # Explode
      echo cast[string]("Oops")
      return
      
  if cname == "dlsym":
    return dlsym

  if injector_handlers.hasKey($cname) == true:
    return injector_handlers[$cname]

  return real_dlsym(handle, cname)
