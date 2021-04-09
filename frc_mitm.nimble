# Package

version       = "0.1.0"
author        = "Jessica Creighton"
description   = "A MITM library for FRC to view/modify FPGA and CAN communication"
license       = "MIT OR Apache-2.0"
srcDir        = "src"
namedBin["frc_interceptor"] = "frc_interceptor.dylib"
#bin           = @["injector"]


# Dependencies

requires "nim >= 1.4.4"
