# ⚡ Hardware-Accelerated Smart Spell-Checking Keyboard

This project implements a hybrid hardware-software system using an **RP2040 Microcontroller** and a **Shrike-Lite FPGA**. It acts as a "Smart Keyboard" that intercepts misspelled words, corrects them in real-time using a frequency dictionary, processes the data through custom FPGA silicon via SPI, and types the corrected sentence directly into your PC as a USB HID device.

## 🏗️ The Architecture Pipeline

This system uses an asymmetrical processing architecture where the microcontroller and the FPGA do exactly what they are best at.

### 1. The Brain: RP2040 (MicroPython / CircuitPython)
The RP2040 acts as the **SPI Master** and high-level system coordinator. 
* **Spell Checking Engine:** It loads a 512-word frequency dictionary (`top512.txt`) and runs an edit-distance algorithm to find the most probable correct spelling of a mistyped word.
* **Hardware Coordinator:** It chunks the corrected string into individual bytes, manages the Chip Select (`CS`) line, and pumps the SPI Clock to communicate with the FPGA.
* **USB HID Interface:** Once the hardware processing is complete, the RP2040 acts as a physical USB keyboard, typing the final corrected output directly into the host PC's active text editor.

### 2. The Muscle: Shrike-Lite FPGA (Verilog)
The Shrike-Lite FPGA acts as the **SPI Target** and low-level hardware pipeline.
* **Hardware Echo & Pipelining:** Currently, the FPGA receives the corrected bytes from the RP2040, registers them into its internal flip-flops, and echoes the final result back across the MISO line on the very next SPI transaction. 
* **Nanosecond Synchronization:** The FPGA operates on a strict 50MHz internal clock. The Verilog logic utilizes a 3-stage synchronizer to catch the RP2040's `CS` drop and align the incoming 100kHz SPI clock to its internal domains.
* **Safe State Logic:** Features internal hardwired resets to prevent floating voltage lock-ups.

---

## 🔌 Hardware Wiring Guide

To replicate this project, you must ensure a **shared Ground (GND)** between the RP2040 and the Shrike-Lite, and wire the SPI bus to the exact default hardware pins:

| Signal | RP2040 Pin | Shrike-Lite FPGA Pin | Description |
| :--- | :--- | :--- | :--- |
| **MOSI (TX)** | `GP19` (Pin 25) | `spi_mosi` | Data from RP2040 to FPGA |
| **MISO (RX)** | `GP16` (Pin 21) | `spi_miso` | Data from FPGA back to RP2040 |
| **SCK** | `GP18` (Pin 24) | `spi_sck` | SPI Clock (Driven by RP2040) |
| **CS / SS** | `GP5` (Pin 7) | `spi_ss_n` | Chip Select (Active Low) |
| **GND** | Any `GND` Pin | Any `GND` Pin | **CRITICAL:** Shared reference voltage |

*(Note: Ensure your Go Configure `.cst` file maps the Verilog variables to the correct physical header pins on your specific Shrike-Lite board).*

---

## 🚀 How It Works (The Data Flow)

1. **Input:** The user types a misspelled string (e.g., `"teh"`).
2. **Software Correction:** The RP2040 algorithm detects the error, checks the frequency dictionary, and corrects `"teh"` to `"the"`.
3. **SPI Transmission:** The RP2040 wraps the string in `\x00` dummy bytes (to flush the hardware pipeline) and sends it over MOSI to the FPGA.
4. **Hardware Synchronization:** A deliberate `5µs` micro-delay in the RP2040 code allows the FPGA's 50MHz clock to register the Chip Select drop before the data transmission begins, preventing dropped bits.
5. **Hardware Echo:** The FPGA registers the bytes and streams the final result back to the RP2040 over MISO.
6. **HID Output:** The RP2040 emulates a USB keyboard and types the final FPGA output directly into Notepad, Word, or any active window on the host PC.

---

## 🛠️ Setup & Installation

### FPGA Setup
1. Open the Go Configure IDE.
2. Load `top.v` and `spi_target.v` into your project.
3. Apply your `.cst` Physical Constraints file to map the SPI pins and the 50MHz Clock.
4. Synthesize and flash the bitstream to the Shrike-Lite.

### RP2040 Setup
1. Flash your RP2040 with **CircuitPython** (recommended for native USB HID support) or use MicroPython with the PC Companion script.
2. Upload `code.py` to the root of your microcontroller.
3. Upload the `top512.txt` dictionary file to the root of your microcontroller.

### Running the System
1. Plug both devices in and ensure the SPI jumper wires are connected.
2. Run `code.py`.
3. Follow the terminal prompts to type a misspelled word, then quickly click your mouse into a text editor.
4. Watch the hardware type out your corrected sentence!

---
*Built with Python, Verilog, and a lot of debugging over serial ports.*
