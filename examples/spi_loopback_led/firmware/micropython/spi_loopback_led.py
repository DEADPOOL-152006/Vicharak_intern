# ================================================================
# SPI Loopback LED - Spell Checker with Hardware Echo
# ================================================================
# Purpose: RP2040-based spell checker that uses an FPGA for
#          hardware-accelerated SPI echo and LED control.
#
# Platform: MicroPython on RP2040 (Shrike-Lite)
# ================================================================

from machine import SPI, Pin
import time

# ================================================================
# SPI Configuration
# ================================================================
# Initialize SPI0 with 500kHz baudrate (Mode 0: CPOL=0, CPHA=0)
spi = SPI(
    0,
    baudrate=500000,
    polarity=0,
    phase=0,
    bits=8
)

# Chip Select Pin (GP5)
cs = Pin(5, Pin.OUT)
cs.value(1)  # CS inactive (High)

# ================================================================
# Dictionary Loading
# ================================================================
# Load a 512-word frequency dictionary from top512.txt
# Format: word,frequency (one per line)
frequency_dict = {}

try:
    with open("top512.txt") as f:
        for line in f:
            line = line.strip()
            if line == "":
                continue
            parts = line.split(",")
            if len(parts) == 2:
                word, freq = parts
                frequency_dict[word] = int(freq)
except:
    print("top512.txt not found")

dictionary = set(frequency_dict.keys())
print(f"Loaded {len(dictionary)} words from dictionary")

# ================================================================
# Spell Correction: Edit Distance Algorithm
# ================================================================

LETTERS = "abcdefghijklmnopqrstuvwxyz"


def edits1(word):
    """
    Generate all possible single-edit edits of a word:
    - Deletions: Remove one character
    - Transpositions: Swap adjacent characters
    - Replacements: Replace one character
    - Insertions: Add one character
    """
    splits = [(word[:i], word[i:]) for i in range(len(word) + 1)]
    deletes = [L + R[1:] for L, R in splits if R]
    transposes = [L + R[1] + R[0] + R[2:] for L, R in splits if len(R) > 1]
    replaces = [L + c + R[1:] for L, R in splits if R for c in LETTERS]
    inserts = [L + c + R for L, R in splits for c in LETTERS]

    return set(deletes + transposes + replaces + inserts)


def spell(word):
    """
    Correct a misspelled word using edit distance and frequency ranking.
    Returns the most frequent corrected candidate.
    """
    if word in dictionary:
        return word

    best = word
    best_freq = 0

    for candidate in edits1(word):
        if candidate in dictionary:
            freq = frequency_dict.get(candidate, 0)
            if freq > best_freq:
                best_freq = freq
                best = candidate

    return best


# ================================================================
# FPGA Echo via SPI
# ================================================================

def fpga_echo(word):
    """
    Transmit corrected word to FPGA and receive echoed result.
    Sends one byte at a time with CS active for each byte.
    """
    echoed = ""

    for ch in word:
        tx = bytearray(1)
        rx = bytearray(1)

        tx[0] = ord(ch)

        cs.value(0)  # CS active (Low)
        spi.write_readinto(tx, rx)
        cs.value(1)  # CS inactive (High)

        # Small delay for FPGA clock synchronization
        time.sleep_us(100)

        # Accumulate echoed result
        echoed += chr(rx[0])

    return echoed


# ================================================================
# Main Loop
# ================================================================

print("\n" + "="*50)
print("SPI Loopback LED Spell Checker")
print("="*50)
print("Type a misspelled word and press Enter.")
print("The FPGA will echo back the corrected word.")
print("="*50 + "\n")

while True:
    try:
        word = input("Word : ").strip().lower()

        if not word:
            continue

        # Spell correction
        corrected = spell(word)

        print()
        print(f"Corrected : {corrected}")

        # Send to FPGA and receive echo
        echoed = fpga_echo(corrected)

        print(f"FPGA Echo : {echoed}")
        print()
    except KeyboardInterrupt:
        print("\nExiting...")
        break
    except Exception as e:
        print(f"Error: {e}")
        print()
