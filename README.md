Supervisory Terminal ST-99
==========================

## A single board embedded computer for supervising multiple devices from a centralized location.

Contact: Ori Novanda (cargmax-at-gmail.com)

I designed and built this embedded system back in 1997-1999. I developed it for supervising multiple devices (from different vendors) from a central location.
The system used the Intel 8052 microcontroller as the main controller. I designed the PCB in two layers. I developed the firmware fully in assembly (MCS-51/52) and provided some hardware functionality through emulator firmware (e.g.  custom alarm sound, I2C bus, and secondary serial port) to save the bill of materials (BOM).

## Features:
*	Addressable I/O ports (expansion bus): to monitor up to 8-bit x 256 devices
*	Addressable slave serial ports (expansion bus): up to 256 RS-232 serial ports
*	Master serial port to communicate to a PC
*	Printer port to log events through an external printer
*	On-board Real Time Clock and Watchdog circuitry
*	Build-in LCD and keypad
*	Alarm sound

## Schematics:

### CPU
![cpu schematic](doc/hw/cpu-sch.png)

### Parallel Expansion Board
![parallel-expansion schematic](doc/hw/parallelexpansion-sch.png)

### Serial Expansion Board
![serial-expansion schematic](doc/hw/serialexpansion-sch.png)

## PCBs:

### Main Board
![main board pcb](doc/hw/mainboard-pcb.png)

### Main Board Component Layout:
![main board top silk-screen](doc/hw/mainboard-top-silk-screen.png)

### Keypad Board
![keypad pcb](doc/hw/keypad-pcb.png)

### Parallel Expansion Board
![parallel-expansion pcb](doc/hw/parallelexpansion-pcb.png)

### Serial Expansion Board
![serial-expansion pcb](doc/hw/serialexpansion-pcb.png)
