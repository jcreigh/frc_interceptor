# Package

version       = "0.1.0"
author        = "Jessica Creighton"
description   = "A MITM library for FRC to (eventually) view/modify FPGA and CAN communication"
license       = "MIT"
srcDir        = "src"
namedBin["frc_interceptor"] = "frc_interceptor.dylib"

# Dependencies

requires "nim >= 1.4.4"
