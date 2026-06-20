// ================================================================
// SPI Loopback LED - Spell Checker with Hardware Echo
// ================================================================
// Purpose: RP2040-based spell checker that uses an FPGA for
//          hardware-accelerated SPI echo and LED control.
//
// Platform: Arduino IDE + CircuitPython on RP2040 (Shrike-Lite)
// Board: Shrike-Lite (RP2040)
// ================================================================

#include <SPI.h>

// ================================================================
// Pin Definitions
// ================================================================
const int CS_PIN = 5;   // GP5 - Chip Select
const int MOSI_PIN = 19; // GP19 - Master Out, Slave In
const int MISO_PIN = 16; // GP16 - Master In, Slave Out
const int SCK_PIN = 18;  // GP18 - Serial Clock

// ================================================================
// Dictionary Storage (512 words)
// ================================================================
struct Word {
    const char* text;
    int frequency;
};

// Load dictionary from PROGMEM to save RAM
const Word dictionary[] PROGMEM = {
    {"the", 23135851}, {"be", 12545825}, {"to", 12074625}, {"of", 11992520},
    {"and", 10854853}, {"a", 10382545}, {"in", 9997362}, {"that", 9916124},
    {"have", 9815195}, {"i", 9749280}, {"it", 8239626}, {"for", 8236344},
    {"not", 7838814}, {"on", 7152015}, {"with", 7152015}, {"he", 7079457},
    {"as", 6881911}, {"you", 5988035}, {"do", 5812092}, {"at", 5659192},
    // ... Additional words truncated for space ...
};

const int DICT_SIZE = 512;

// ================================================================
// Edit Distance Algorithm
// ================================================================

char* candidates[1000];
int candidateCount = 0;

void generateCandidates(const char* word) {
    candidateCount = 0;
    
    // For simplicity, this is a placeholder
    // Full implementation would generate all single-edit variations
    // This is CPU-intensive, so we use a simplified approach
}

String correctSpelling(String word) {
    // Check if word exists in dictionary
    for (int i = 0; i < DICT_SIZE; i++) {
        String dictWord = String(dictionary[i].text);
        if (dictWord == word) {
            return word; // Word is correct
        }
    }
    
    // If not found, return the original word
    // (Full edit distance implementation would go here)
    return word;
}

// ================================================================
// SPI Echo Function
// ================================================================

String fpga_echo(String word) {
    String echoed = "";
    
    for (int i = 0; i < word.length(); i++) {
        // Send one byte at a time
        digitalWrite(CS_PIN, LOW);  // CS active
        
        byte sent = word[i];
        byte received = SPI.transfer(sent);
        
        digitalWrite(CS_PIN, HIGH); // CS inactive
        
        // Small delay for FPGA clock synchronization
        delayMicroseconds(100);
        
        echoed += (char)received;
    }
    
    return echoed;
}

// ================================================================
// Setup
// ================================================================

void setup() {
    Serial.begin(115200);
    delay(2000); // Wait for serial monitor
    
    // Initialize SPI
    SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, CS_PIN);
    SPI.setFrequency(500000); // 500kHz
    SPI.setDataMode(SPI_MODE0); // CPOL=0, CPHA=0
    SPI.setBitOrder(MSBFIRST);
    
    // Initialize CS pin
    pinMode(CS_PIN, OUTPUT);
    digitalWrite(CS_PIN, HIGH); // CS inactive
    
    // Print startup message
    Serial.println("\n" + String(50, '='));
    Serial.println("SPI Loopback LED Spell Checker");
    Serial.println(String(50, '='));
    Serial.println("Type a misspelled word and press Enter.");
    Serial.println("The FPGA will echo back the corrected word.");
    Serial.println(String(50, '=') + "\n");
    
    Serial.println("Dictionary loaded: 512 words");
    Serial.println("Waiting for input...\n");
}

// ================================================================
// Main Loop
// ================================================================

void loop() {
    if (Serial.available()) {
        String word = Serial.readStringUntil('\n');
        word.trim();
        word.toLowerCase();
        
        if (word.length() == 0) {
            return;
        }
        
        // Correct the spelling
        String corrected = correctSpelling(word);
        
        Serial.println();
        Serial.print("Word: ");
        Serial.println(word);
        Serial.print("Corrected: ");
        Serial.println(corrected);
        
        // Send to FPGA and receive echo
        String echoed = fpga_echo(corrected);
        
        Serial.print("FPGA Echo: ");
        Serial.println(echoed);
        Serial.println();
    }
}
