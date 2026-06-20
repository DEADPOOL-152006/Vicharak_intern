// ================================================================
// SPI Loopback Echo Top Module
// ================================================================
// Purpose: Implements a simple SPI target that receives data from
//          an RP2040 SPI master, registers it, and echoes it back
//          while controlling an LED based on received commands.
//
// Clock: 50MHz system clock
// SPI Mode: Mode 0 (CPOL=0, CPHA=0)
// ================================================================

(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,     // System Clock (50MHz)
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input rst_n,                   // System Reset (Active Low)

    // Physical SPI Pins (Connect these to FPGA I/O)
    (* iopad_external_pin *) input spi_ss_n,                // Chip Select (Active Low)
    (* iopad_external_pin *) input spi_sck,                 // SPI Clock
    (* iopad_external_pin *) input spi_mosi,                // Master Out, Slave In
    (* iopad_external_pin *) output spi_miso,               // Master In, Slave Out
    (* iopad_external_pin *) output spi_miso_en,            // MISO Output Enable

    // Physical LED Pins
    (* iopad_external_pin *) output reg led,                // LED Output
    (* iopad_external_pin *) output led_en                  // LED Output Enable
);

    // Clock and output enables
    assign led_en = 1'b1;
    assign clk_en = 1'b1;

    // Internal wires from SPI target module
    wire [7:0] rx_data_wire;
    wire       rx_valid_pulse;
    reg  [7:0] tx_data_reg;

    // ================================================================
    // Echo Logic: Store received byte and echo back on next transmission
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= 8'h00;
        end else if (rx_valid_pulse) begin
            tx_data_reg <= rx_data_wire;  // Echo received data
        end
    end

    // ================================================================
    // LED Control Logic
    // ================================================================
    // 0xAB = Turn LED ON
    // 0xFF = Turn LED OFF
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led <= 1'b0;
        end else if (rx_valid_pulse) begin
            if (rx_data_wire == 8'hAB)
                led <= 1'b1;              // LED ON
            else if (rx_data_wire == 8'hFF)
                led <= 1'b0;              // LED OFF
        end
    end

    // ================================================================
    // SPI Target Instance
    // ================================================================
    spi_target #(
        .CPOL(1'b0),                      // Standard Mode 0 (Idle Low)
        .CPHA(1'b0),                      // Standard Mode 0 (Sample Rising Edge)
        .WIDTH(8),                        // 8-bit data width
        .LSB(1'b0)                        // MSB First (Standard)
    ) u_spi_target (
        // System Common
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_enable(1'b1),                  // Enable module permanently

        // SPI Physical Interface
        .i_ss_n(spi_ss_n),
        .i_sck(spi_sck),
        .i_mosi(spi_mosi),
        .o_miso(spi_miso),
        .o_miso_oe(spi_miso_en),

        // RX Interface (Data FROM MCU)
        .o_rx_data(rx_data_wire),
        .o_rx_data_valid(rx_valid_pulse),

        // TX Interface (Data TO MCU)
        .i_tx_data(tx_data_reg),
        .o_tx_data_hold()                 // Not needed for simple echo
    );

endmodule
