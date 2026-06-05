import time
from machine import Pin, UART

print("==========================================================")
print("Engaging High-Speed Burst Packet Reader (FIFO Alignment)")
print("==========================================================")

# Initialize UART0 at 115200 baud with a comfortable read timeout
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1), timeout=30)
time.sleep_ms(100)

def transmit_and_read_buffer(word_str):
    print(f"\n[Sending Word]: '{word_str}'")
    
    # 1. Clear any residual noise out of the hardware RX buffer
    if uart.any():
        uart.read()
        
    # 2. Write the 4-byte target word to the FPGA
    uart.write(word_str)
    
    # 3. Give the FPGA FSM time to push data into the FIFO and stream it out
    time.slee