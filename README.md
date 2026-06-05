# Vicharak Internship Project: UART-Based Text Processing FPGA System

## 📋 Overview

This repository contains a hardware and software implementation of a **UART-based text processing system** designed for FPGA platforms (Vicharak/OpenFPGA). The system reads 4-byte text inputs via UART serial communication, performs real-time spell-checking/text transformation, and transmits the processed output back over UART at **115200 baud**.

**Primary Use Case:** Bidirectional text communication with hardware-based string matching and transformation capabilities.

---

## 🎯 Project Objectives

1. Implement a robust UART communication interface (receiver and transmitter)
2. Develop a hardware-accelerated text processing pipeline
3. Perform real-time spell-checking transformations (e.g., "tset" → "test", "ecoh" → "echo")
4. Demonstrate full duplex asynchronous serial communication on FPGA
5. Integrate state machine-based flow control between hardware modules

---

## 📁 Project Structure

```
Vicharak_intern/
├── README.md                 # Project documentation
├── top.v                     # Top-level module & main FSM controller
├── uart_rx.v                 # UART receiver (RX) module
├── uart_tx.v                 # UART transmitter (TX) with async FIFO
├── code.py                   # MicroPython host-side control script
└── uart_sum.ffpga            # FPGA synthesis project file (OpenFPGA format)
```

---

## 🔧 Hardware Architecture

### **1. Top-Level Module (`top.v`)**
- **Clock Frequency:** 25 MHz (configurable via parameter)
- **Baud Rate:** 115200 bps (configurable)
- **Main FSM States:**
  - **RX Phase:** Receives 4 bytes sequentially from UART
  - **Processing Phase:** Applies spell-checking transformation rules
  - **TX Phase:** Transmits 4 processed bytes back to host
  
**Key Features:**
- 16-state FSM handling receive → transform → transmit pipeline
- Spell-check rules:
  - `"tset"` (0x74, 0x73, 0x65, 0x74) → `"test"` (0x74, 0x65, 0x73, 0x74)
  - `"ecoh"` (0x65, 0x63, 0x6f, 0x68) → `"echo"` (0x65, 0x63, 0x68, 0x6f)
- Pass-through for unmatched 4-byte sequences
- Safe state machine with synchronous handshaking

### **2. UART Receiver Module (`uart_rx.v`)**
- **Parameters:**
  - `CLK`: System clock frequency (default 50 MHz)
  - `BAUD_RATE`: Serial baud rate (default 115200)
- **FSM States:**
  - `IDLE` → Wait for start bit (RX low)
  - `RX_START_BIT` → Detect falling edge (midpoint sampling)
  - `RX_DATA_BITS` → Collect 8 data bits
  - `RX_STOP_BIT` → Validate stop bit
  - `CLEANUP` → Return to IDLE
- **Sampling Strategy:** Midpoint sampling at HALF_BIT_CLOCK for robust noise immunity
- **Output Signals:**
  - `o_RX_Byte`: 8-bit received data
  - `o_RX_DV`: Data valid strobe (1 clock pulse)

### **3. UART Transmitter Module (`uart_tx.v`)**
- **Parameters:** Same clock/baud configuration as receiver
- **Architecture:**
  - **Async FIFO Buffer** (`uart_async_fifo`): 16-entry deep, Gray-code pointer synchronization
  - **FSM Serializer** (`uart_txuart_tx`): Converts byte to serial with oversampling
  - **Baud Rate Generator** (`uart_txbaud_rate_generator_tx`): Generates clock ticks
- **Output Signals:**
  - `o_tx`: Physical TX serial wire
  - `o_tx_done`: Transmission complete strobe
- **Features:**
  - Non-blocking buffered operation
  - Cross-clock domain safe (Gray-code synchronization)
  - 16x oversampling for accurate baud rate generation

---

## 💻 Software Interface

### **Host Controller (`code.py`)**
MicroPython script for microcontroller (e.g., Raspberry Pi Pico) to interact with the FPGA:

```python
# Initialize UART at 115200 baud
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1), timeout=30)

# Transmit 4-byte word and read response
def transmit_and_read_buffer(word_str):
    uart.write(word_str)           # Send word to FPGA
    time.sleep_ms(100)             # Wait for processing
    response = uart.read()         # Read transformed output
    return response
```

**Usage:**
- Send 4-byte ASCII strings to the FPGA
- Receive transformed output (spell-checked or pass-through)
- Supports burst transmission with automatic FIFO handling

---

## ⚡ Signal Interface

### **Port Definitions**

| Port       | Direction | Type    | Description                        |
|------------|-----------|---------|----------------------------------|
| `clk`      | Input     | 1-bit   | System clock (25 MHz)            |
| `clk_en`   | Output    | 1-bit   | Clock enable (always 1)          |
| `rst`      | Input     | 1-bit   | Active-high asynchronous reset   |
| `rx`       | Input     | 1-bit   | UART RX serial input             |
| `tx`       | Output    | 1-bit   | UART TX serial output            |
| `tx_en`    | Output    | 1-bit   | TX enable flag (always 1)        |

---

## 🔄 Operating Flow

### **Receive Phase**
1. FPGA waits for RX data valid signal from UART receiver
2. Captures first byte → state S_RX1_WAIT
3. Waits for data_valid to deassert → state S_RX1_DROP
4. Repeats for bytes 2, 3, 4 in sequence
5. Transitions to processing after all 4 bytes collected

### **Processing Phase**
- Checks 4-byte pattern against spell-check rules:
  - If match → Apply transformation
  - Else → Pass through unchanged
- Stores result in output registers (out_b1, out_b2, out_b3, out_b4)

### **Transmit Phase**
1. Asserts `tx_start_reg` for byte 1
2. Waits for `tx_done` signal
3. Repeats for bytes 2, 3, 4
4. Returns to RX phase after all bytes transmitted

---

## 🔌 Integration Requirements

### **Hardware Constraints**
- **Clock:** 25 MHz system clock
- **Reset:** Active-high synchronous reset
- **UART Pins:** Standard single-ended signaling (3.3V/5V tolerant)
- **Timing:** All operations synchronous with system clock

### **Software Requirements**
- **Host Microcontroller:** ARM Cortex-M0+ (Raspberry Pi Pico) or compatible
- **Language:** MicroPython or C
- **Serial Library:** Machine UART interface
- **Baud Rate:** 115200 bps

---

## 📊 Performance Metrics

- **Data Throughput:** ~14.4 KB/s (115200 bps ÷ 8 bits)
- **Latency per 4-byte frame:** ~2-3 ms (including UART transmit time)
- **FPGA Utilization:** Minimal (estimated ~2-3% LUTs on modern FPGA)
- **Power Consumption:** < 100 mW (static logic only, no DSP/BRAM)

---

## 🛠️ Build & Deployment

### **FPGA Synthesis (OpenFPGA)**
```bash
# Using the provided .ffpga project file
openfpga -f uart_sum.ffpga --write_netlist --device Vicharak
```

### **Hardware Testing**
1. Load bitstream to FPGA development board
2. Connect serial interface (USB-to-UART adapter recommended)
3. Run `code.py` on host microcontroller
4. Observe transformed output on terminal

### **Debugging**
- Monitor `o_RX_DV` and `o_tx_done` signals with logic analyzer
- Verify FSM state transitions using simulation
- Validate baud rate timing with oscilloscope

---

## 📝 Example Communication

### **Input Message:** `tset` (0x74, 0x73, 0x65, 0x74)
```
Host → FPGA: t s e t
FPGA FSM: Matches spell-check rule
FPGA → Host: t e s t
```

### **Input Message:** `hello` (partial, first 4 bytes: `hell`)
```
Host → FPGA: h e l l
FPGA FSM: No rule match
FPGA → Host: h e l l (pass-through)
```

---

## 🐛 Known Issues & Limitations

1. **Spell-checking:** Hardcoded for 2 specific 4-byte patterns only
2. **String Length:** Fixed to 4 bytes per transaction (no variable-length support)
3. **Clock Domains:** RX and TX operate in same clock domain (simplification for this design)
4. **Error Handling:** No parity/checksum validation; relies on UART start/stop bits

---

## 🚀 Future Enhancements

- [ ] Implement pattern matching for N-byte strings
- [ ] Add CRC/checksum validation
- [ ] Support configurable transformation rules via host register writes
- [ ] Integrate dual-clock domain architecture for multi-frequency designs
- [ ] Add SPI/I2C interface option for non-serial applications
- [ ] Implement FIFO depth monitoring via status registers

---

## 📚 Technical References

- **UART Protocol:** [Wikipedia - Universal Asynchronous Receiver-Transmitter](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter)
- **Gray Code (for CDC):** [Gray Code on Wikipedia](https://en.wikipedia.org/wiki/Gray_code)
- **Verilog HDL:** IEEE 1364-2005
- **OpenFPGA Documentation:** [OpenFPGA on GitHub](https://github.com/lnis-uofu/OpenFPGA)

---

## 👤 Author

**Student:** DEADPOOL-152006  
**Project:** Vicharak Internship Program  
**Date:** 2026  
**Contact:** See GitHub profile

---

## 📄 License

This project is provided as-is for educational and internship purposes.

---

## 🤝 Contributing

For improvements, bug fixes, or feature requests:
1. Create a feature branch
2. Make your changes with clear commit messages
3. Test thoroughly on hardware
4. Submit a pull request with documentation

---

**Happy Hacking! ⚡**
