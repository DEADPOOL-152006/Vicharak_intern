import serial
import keyboard
import time

PICO_PORT = 'COM4' 

try:
    # We add a timeout so it doesn't freeze forever if the Pico is quiet
    ser = serial.Serial(PICO_PORT, 115200, timeout=1)
    print(f"Connected to Pico on {PICO_PORT}!")
    
    while True:
        # 1. Get the misspelled word from you
        word_to_test = input("\nType a misspelled word here (e.g. 'teh') and press Enter: ")
        
        # 2. Give you time to click into your text editor
        print("Quick! Click your mouse inside Notepad or Word...")
        for i in range(30, 0, -1):
            print(f"{i}...")
            time.sleep(1)
        
        # 3. Send the word to the Pico (the \r\n acts as the 'Enter' key)
        ser.write((word_to_test + '\r\n').encode('utf-8'))
        
        # 4. Listen for the Pico and FPGA to do their magic
        while True:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            
            # If we see the FPGA Echo line, grab the text and type it!
            if line.startswith("FPGA Echo :"):
                echoed_text = line.replace("FPGA Echo :", "").strip()
                
                # Type it out like a real keyboard!
                keyboard.write(f"You typed: {word_to_test} | FPGA Corrected: {echoed_text}\n")
                print(f"Success! Typed '{echoed_text}' into your editor.")
                break
                
except Exception as e:
    print(f"Error: {e}")
    print("Make sure Thonny is CLOSED so the port is free!")
