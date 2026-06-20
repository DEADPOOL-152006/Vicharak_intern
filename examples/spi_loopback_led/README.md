# SPI Loopback LED

**Difficulty:** Intermediate  
**Uses MCU:** Yes  
**External Hardware:** None

## Overview

This example demonstrates a hardware-accelerated spell-checking keyboard using an RP2040 microcontroller and Shrike-Lite FPGA. The system intercepts misspelled words, corrects them using a frequency dictionary, and echoes the result through an SPI interface. The FPGA also controls an LED based on received commands.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested |
| Shrike (RP2350) | `firmware/arduino-ide/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required. Connect the following SPI pins between RP2040 and Shrike-Lite FPGA:

| Signal | RP2040 Pin | Shrike-Lite Pin | Description |
|--------|-----------|-----------------|-------------|
| **MOSI (TX)** | `GP19` (Pin 25) | `spi_mosi` | Data from RP2040 to FPGA |
| **MISO (RX)** | `GP16` (Pin 21) | `spi_miso` | Data from FPGA back to RP2040 |
| **SCK** | `GP18` (Pin 24) | `spi_sck` | SPI Clock (Driven by RP2040) |
| **CS / SS** | `GP5` (Pin 7) | `spi_ss_n` | Chip Select (Active Low) |
| **GND** | Any `GND` Pin | Any `GND` Pin | **CRITICAL:** Shared reference voltage |

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike-Lite board via USB
2. Upload `bitstream/spi_loopback_led.bin` using ShrikeFlash
3. Flash the RP2040 with CircuitPython
4. Upload `spi_loopback_led.ino` to the root of your microcontroller
5. Upload `top512.txt` dictionary file to the root
6. Connect the SPI jumper wires between RP2040 and Shrike-Lite
7. Run the firmware and type a misspelled word in the terminal

## Build From Source

### FPGA (Verilog)

1. Open `spi_loopback_led.ffpga` in Go Configure Software Hub
2. Load `ffpga/src/top.v` and `ffpga/src/spi_target.v` into your project
3. Apply your `.cst` Physical Constraints file to map the SPI pins and 50MHz clock
4. Click Synthesize → Generate Bitstream
5. Output will be in `ffpga/build/`
6. Copy the `.bin` file to `bitstream/spi_loopback_led.bin`

### Firmware (Arduino / CircuitPython)

1. Flash your RP2040 with **CircuitPython** (recommended for native USB HID support)
2. Upload `spi_loopback_led.ino` to the root of your microcontroller
3. Upload `top512.txt` dictionary file to the root
4. Connect the SPI wires as shown in Hardware Setup
5. Open serial monitor and run the sketch

## How It Works

### Architecture Pipeline

This system uses an asymmetrical processing architecture where each component handles what it does best:

**RP2040 (Spell Checker):**
- Loads a 512-word frequency dictionary from `top512.txt`
- Implements an edit-distance algorithm to find misspelled words
- Acts as SPI Master, controlling the Chip Select (`CS`) line and SPI Clock
- Chunks corrected strings into individual bytes and transmits over MOSI
- Handles hardware synchronization with a 100µs micro-delay to allow FPGA clock alignment

**Shrike-Lite FPGA (Hardware Echo Pipeline):**
- Acts as SPI Target receiving data from the RP2040
- Registers incoming bytes into internal flip-flops with a 50MHz internal clock
- Uses a 3-stage synchronizer to catch the RP2040's CS drop and align the SPI clock
- Echoes received bytes back to the RP2040 over the MISO line
- Controls an LED based on special control bytes (0xAB = ON, 0xFF = OFF)
- Features internal hardwired resets to prevent floating voltage lock-ups

### Data Flow

1. **Input:** User types a misspelled word (e.g., `"teh"`)
2. **Software Correction:** RP2040 detects the error, checks the frequency dictionary, and corrects to `"the"`
3. **SPI Transmission:** RP2040 wraps the string in `\x00` dummy bytes and sends over MOSI
4. **Hardware Synchronization:** A 100µs micro-delay allows the FPGA's 50MHz clock to register the CS drop before transmission begins
5. **Hardware Echo:** FPGA registers bytes and streams the result back over MISO
6. **Output:** RP2040 displays the echoed result in the serial terminal

## Expected Output

When you run the sketch:

```
==================================================
SPI Loopback LED Spell Checker
==================================================
Type a misspelled word and press Enter.
The FPGA will echo back the corrected word.
==================================================

Word : teh

Corrected : the
FPGA Echo : the

Word : helo

Corrected : hello
FPGA Echo : hello
```

The FPGA echoes back the corrected word and controls the LED:
- Send `0xAB` to turn the LED **ON**
- Send `0xFF` to turn the LED **OFF**

## Key Features

✨ **Hardware-Accelerated Processing** — FPGA handles real-time SPI communication and echo logic  
⚡ **Spell Correction** — 512-word frequency dictionary with edit-distance algorithm  
🔧 **Nanosecond Synchronization** — 3-stage synchronizer for reliable cross-clock-domain handshakes  
🛡️ **Safe State Logic** — Hardwired resets prevent floating voltage lock-ups  
📚 **Educational** — Clear examples of MCU-FPGA communication and hardware pipelining  

## Troubleshooting

**Issue:** FPGA doesn't echo data back
- **Check:** Verify SPI jumper wires are connected securely
- **Check:** Ensure CS pin is connected and properly configured (active low)
- **Check:** Confirm `.cst` file correctly maps `spi_mosi`, `spi_miso`, `spi_sck`, `spi_ss_n` to physical pins
- **Check:** Verify bitstream was successfully flashed to FPGA

**Issue:** RP2040 can't read echoed data
- **Check:** MISO pin must be wired from FPGA output `spi_miso`
- **Check:** Verify all SPI pins match the Hardware Setup table
- **Check:** Serial monitor should show "Loaded 512 words from dictionary"

**Issue:** LED doesn't toggle
- **Check:** Ensure the received byte matches `0xAB` (ON) or `0xFF` (OFF)
- **Check:** Verify LED physical connection to the correct Shrike-Lite pin
- **Check:** Test with a simple LED control script first

**Issue:** Dictionary not loading
- **Check:** Ensure `top512.txt` is in the root directory of the microcontroller
- **Check:** File must be named exactly `top512.txt` (case-sensitive)

## References

- [Shrike Documentation](https://vicharak-in.github.io/shrike/)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)
- [CircuitPython Documentation](https://docs.circuitpython.org/)
- [SPI Protocol Reference](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)
- [Edit Distance Algorithm](https://en.wikipedia.org/wiki/Edit_distance)
