// ===========================================================================
// ROBUST MIDPOINT SAMPLING UART RECEIVER MODULE
// ===========================================================================
module uart_rx #(
    parameter CLK = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input         i_Clock,
    input         i_RX_Serial,
    output        o_RX_DV, 
    output [7:0]  o_RX_Byte
);

  localparam RAW_CLOCKS_PER_BIT = CLK / BAUD_RATE;

  parameter [15:0] CLOCKS_PER_BIT = RAW_CLOCKS_PER_BIT[15:0];
  parameter [15:0] HALF_BIT_CLOCK = (RAW_CLOCKS_PER_BIT[15:0] >> 1);

  localparam [2:0] IDLE         = 3'b000;
  localparam [2:0] RX_START_BIT = 3'b001;
  localparam [2:0] RX_DATA_BITS = 3'b010;
  localparam [2:0] RX_STOP_BIT  = 3'b011;
  localparam [2:0] CLEANUP      = 3'b100;

  reg [15:0] r_Clock_Count = 16'd0;
  reg [2:0]  r_Bit_Index   = 3'd0;
  reg [7:0]  r_RX_Byte     = 8'd0;
  reg        r_RX_DV       = 1'b0;
  reg [2:0]  r_SM_Main     = 3'b000;

  always @(posedge i_Clock) begin
      case (r_SM_Main)
          IDLE: begin
              r_RX_DV       <= 1'b0;
              r_Clock_Count <= 16'd0;
              r_Bit_Index   <= 3'd0;
              if (i_RX_Serial == 1'b0) r_SM_Main <= RX_START_BIT;
              else                     r_SM_Main <= IDLE;
          end
          RX_START_BIT: begin
              if (r_Clock_Count == HALF_BIT_CLOCK) begin
                  if (i_RX_Serial == 1'b0) begin
                      r_Clock_Count <= 16'd0;
                      r_SM_Main     <= RX_DATA_BITS;
                  end else
                      r_SM_Main     <= IDLE;
              end else begin
                  r_Clock_Count <= r_Clock_Count + 1'b1;
              end
          end
          RX_DATA_BITS: begin
              if (r_Clock_Count < (CLOCKS_PER_BIT - 16'd1)) begin
                  r_Clock_Count <= r_Clock_Count + 1'b1;
              end else begin
                  r_Clock_Count          <= 16'd0;
                  r_RX_Byte[r_Bit_Index] <= i_RX_Serial;
                  if (r_Bit_Index < 3'd7) begin
                      r_Bit_Index <= r_Bit_Index + 1'b1;
                  end else begin
                      r_Bit_Index <= 3'd0;
                      r_SM_Main   <= RX_STOP_BIT;
                  end
              end
          end
          RX_STOP_BIT: begin
              if (r_Clock_Count < (CLOCKS_PER_BIT - 16'd1)) begin
                  r_Clock_Count <= r_Clock_Count + 1'b1;
              end else begin
                  r_RX_DV       <= 1'b1;
                  r_Clock_Count <= 16'd0;
                  r_SM_Main     <= CLEANUP;
              end
          end
          CLEANUP: begin
              r_SM_Main <= IDLE;
              r_RX_DV   <= 1'b0;
          end
          default: r_SM_Main <= IDLE;
      endcase
  end

  assign o_RX_Byte = r_RX_Byte;
  assign o_RX_DV   = r_RX_DV;
endmodule