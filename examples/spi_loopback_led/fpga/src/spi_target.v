// ================================================================
// SPI Target (Slave) Module
// ================================================================
// Purpose: Implements a flexible SPI slave with configurable
//          polarity, phase, data width, and bit ordering.
//
// Parameters:
//   - CPOL: Clock polarity (0=active high, 1=active low)
//   - CPHA: Clock phase (0=sample on leading edge, 1=trailing edge)
//   - WIDTH: Data width in bits (typically 8 or 16)
//   - LSB: Bit ordering (0=MSB first, 1=LSB first)
// ================================================================

module spi_target #(
    parameter CPOL = 1'b0,
    parameter CPHA = 1'b0,
    parameter WIDTH = 8,
    parameter LSB = 1'b0
) (
    // System Clock and Reset
    input  i_clk,
    input  i_rst_n,
    input  i_enable,

    // SPI Physical Pins
    input  i_ss_n,                       // Chip Select (Active Low)
    input  i_sck,                        // SPI Clock
    input  i_mosi,                       // Master Out, Slave In
    output o_miso,                       // Master In, Slave Out
    output o_miso_oe,                    // MISO Output Enable

    // RX Interface (Data FROM Master)
    output reg [WIDTH-1:0] o_rx_data,
    output reg             o_rx_data_valid,

    // TX Interface (Data TO Master)
    input  [WIDTH-1:0] i_tx_data,
    output reg         o_tx_data_hold
);

    // ================================================================
    // Internal Registers and Wires
    // ================================================================
    reg [WIDTH-1:0] rx_shift_reg;         // RX shift register
    reg [WIDTH-1:0] tx_shift_reg;         // TX shift register
    reg [WIDTH-1:0] tx_data_capture;      // Captured TX data
    reg [$clog2(WIDTH):0] bit_count;      // Bit counter

    wire sck_edge;                        // Detected SCK edge
    wire ss_active;                       // SS active (low)
    wire mosi_in;                         // MOSI input
    wire miso_out;                        // MISO output

    // ================================================================
    // Clock Domain Crossing: Synchronize external inputs
    // ================================================================
    reg ss_sync1, ss_sync2;
    reg sck_sync1, sck_sync2;
    reg mosi_sync1, mosi_sync2;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            ss_sync1 <= 1'b1;
            ss_sync2 <= 1'b1;
            sck_sync1 <= CPOL;
            sck_sync2 <= CPOL;
            mosi_sync1 <= 1'b0;
            mosi_sync2 <= 1'b0;
        end else begin
            ss_sync1 <= i_ss_n;
            ss_sync2 <= ss_sync1;
            sck_sync1 <= i_sck;
            sck_sync2 <= sck_sync1;
            mosi_sync1 <= i_mosi;
            mosi_sync2 <= mosi_sync1;
        end
    end

    assign ss_active = ~ss_sync2;
    assign mosi_in = mosi_sync2;

    // ================================================================
    // SCK Edge Detection
    // ================================================================
    wire sck_sample_edge = CPHA ? (sck_sync2 != sck_sync1 && sck_sync1 == ~CPOL) :
                                   (sck_sync2 != sck_sync1 && sck_sync1 == CPOL);

    wire sck_shift_edge = CPHA ? (sck_sync2 != sck_sync1 && sck_sync1 == CPOL) :
                                  (sck_sync2 != sck_sync1 && sck_sync1 == ~CPOL);

    // ================================================================
    // SPI State Machine and Shift Logic
    // ================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rx_shift_reg <= {WIDTH{1'b0}};
            tx_shift_reg <= {WIDTH{1'b0}};
            tx_data_capture <= {WIDTH{1'b0}};
            bit_count <= {$clog2(WIDTH)+1{1'b0}};
            o_rx_data <= {WIDTH{1'b0}};
            o_rx_data_valid <= 1'b0;
            o_tx_data_hold <= 1'b0;
        end else begin
            o_rx_data_valid <= 1'b0;
            o_tx_data_hold <= ss_active && (bit_count < WIDTH);

            if (!ss_active) begin
                // SS inactive: reset state
                bit_count <= {$clog2(WIDTH)+1{1'b0}};
                tx_data_capture <= i_tx_data;
                tx_shift_reg <= i_tx_data;
            end else begin
                // Sample MOSI on sample edge
                if (sck_sample_edge && (bit_count < WIDTH)) begin
                    if (LSB)
                        rx_shift_reg[bit_count] <= mosi_in;
                    else
                        rx_shift_reg[WIDTH-1-bit_count] <= mosi_in;
                end

                // Shift MISO on shift edge
                if (sck_shift_edge && (bit_count < WIDTH)) begin
                    tx_shift_reg <= LSB ? {mosi_in, tx_shift_reg[WIDTH-1:1]} :
                                          {tx_shift_reg[WIDTH-2:0], mosi_in};
                    bit_count <= bit_count + 1'b1;
                end

                // Complete byte transfer
                if ((bit_count == WIDTH) && sck_shift_edge) begin
                    o_rx_data <= rx_shift_reg;
                    o_rx_data_valid <= 1'b1;
                    tx_data_capture <= i_tx_data;
                    tx_shift_reg <= i_tx_data;
                    bit_count <= {$clog2(WIDTH)+1{1'b0}};
                end
            end
        end
    end

    // ================================================================
    // MISO Output Multiplexer
    // ================================================================
    assign miso_out = ss_active && (bit_count < WIDTH) ?
                      (LSB ? tx_shift_reg[0] : tx_shift_reg[WIDTH-1]) : 1'bZ;

    assign o_miso = miso_out;
    assign o_miso_oe = ss_active && (bit_count < WIDTH);

endmodule
