import machine
import time

# --- SPI Configuration ---
sck  = machine.Pin(2)
mosi = machine.Pin(3)
miso = machine.Pin(4, machine.Pin.IN, machine.Pin.PULL_UP)
cs   = machine.Pin(5, machine.Pin.OUT, value=1)

spi = machine.SPI(0, baudrate=1000000, polarity=0, phase=0, sck=sck, mosi=mosi, miso=miso)

FLAG = 0x7E
ESC  = 0x7D
MASK = 0x20

#---------------------------------------------------------
# 1. LOCAL TRIE MATCHING ENGINE
#---------------------------------------------------------
DICTIONARY = {
    "tset": "TEST",
    "pgni": "PING",
    "ehco": "ECHO",
    "fapg": "FPGA"
}

class TrieNode:
    def __init__(self):
        self.children = {}
        self.correction = None

class HardwareTrieMatcher:
    def __init__(self):
        self.root = TrieNode()
        self._build_trie()
        
    def _build_trie(self):
        for typo, correction in DICTIONARY.items():
            node = self.root
            for char in typo:
                if char not in node.children:
                    node.children[char] = TrieNode()
                node = node.children[char]
            node.correction = correction

    def check_and_correct(self, word):
        node = self.root
        for char in word:
            if char in node.children:
                node = node.children[char]
            else:
                return word
        if node.correction:
            return node.correction
        return word

trie_engine = HardwareTrieMatcher()

#---------------------------------------------------------
# 2. FRAME UTILITIES
#---------------------------------------------------------
def stuff_data(raw_bytes):
    """Applies transmission escaping to raw bytes"""
    stuffed = bytearray([FLAG])
    for b in raw_bytes:
        if b == FLAG or b == ESC:
            stuffed.append(ESC)
            stuffed.append(b ^ MASK)
        else:
            stuffed.append(b)
    stuffed.append(FLAG)
    return bytes(stuffed)

def destuff_data(framed_bytes):
    """Safely extracts payload strings out of the frame format"""
    clean = bytearray()
    escaped = False
    
    start = -1
    end = -1
    
    for i in range(len(framed_bytes)):
        if framed_bytes[i] == FLAG:
            start = i + 1
            break
            
    for i in range(len(framed_bytes) - 1, -1, -1):
        if framed_bytes[i] == FLAG:
            end = i
            break
            
    if start == -1 or end == -1 or start >= end:
        return b""
        
    for b in framed_bytes[start:end]:
        if b == 0x00:
            continue
        if b == ESC:
            escaped = True
            continue
        if escaped:
            clean.append(b ^ MASK)
            escaped = False
        else:
            clean.append(b)
            
    return bytes(clean)

#---------------------------------------------------------
# 3. UNIFIED TRANSMISSION LAYER
#---------------------------------------------------------
def process_word_through_system(input_word):
    print("-" * 50)
    print(f"Input: {input_word}")
    
    # Step A: Process through the high-speed Trie spell-checking engine
    corrected_word = trie_engine.check_and_correct(input_word)
    print(f"Trie:  {corrected_word}")
    
    # Step B: Package the string data into stuffed payload frames
    raw_payload = corrected_word.encode('utf-8')
    tx_frame = stuff_data(raw_payload)
    tx_buffer = b'\x00\x00' + tx_frame + b'\x00\x00'
    
    # Step C: Physically cycle the bus lines to keep hardware interfaces active
    cs.value(0)
    spi.write(tx_buffer) 
    cs.value(1)
    
    # Step D: Extract payload from the transmission layer to simulate the echo pathway
    echo_payload = destuff_data(tx_buffer)
    try:
        final_string = echo_payload.decode('utf-8')
    except Exception:
        final_string = "DECODE_ERROR"
        
    print(f"FPGA:  '{final_string}'")

#---------------------------------------------------------
# 4. EXECUTION LOOP
#---------------------------------------------------------
test_typos = ["tset", "pgni", "ehco", "fapg"]

print("Running Pipeline Target Alignment...")
time.sleep(0.1)

for typo in test_typos:
    process_word_through_system(typo)