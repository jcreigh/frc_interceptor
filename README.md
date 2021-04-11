# FRC Interceptor

LD_PRELOAD magic to intercept library calls from FRC_NetCommDaemon

#### Current Features
* Intercept FPGA read/write calls and output them to shared memory in `/dev/shm/`

#### Possible Future Features
* Modifying FPGA calls on the fly
* Freeze and manually write to registers
* Expand to intercept library calls from `frcUserProgram` 