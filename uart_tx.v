// ===========================================================================
// PERFECTLY CLEAN ASYNCHRONOUS UART TRANSMITTER WITH DUAL-CLOCK FIFO
// ===========================================================================
module uart_tx #(
  parameter IN_CLK_HZ         = 50_000_000, 
  parameter DATA_FRAME        = 8,          
  parameter BAUD_RATE         = 115_200,    
  parameter OVERSAMPLING_MODE = 16,        
  parameter STOP_BIT          = 1,          
  parameter LSB               = 1'b0        
) (
  input                   i_clk,        // System Clock (Fast)
  input                   i_rst,        // Global Reset
  output                  o_tx,         // Physical Serial Wire out
  input  [DATA_FRAME-1:0] i_tx_data,    // High-speed incoming data
  input                   i_tx_start,   // Push data strobe
  output                  o_tx_done     // Transmission cycle fully complete
);

  wire w_tick;
  wire [DATA_FRAME-1:0] fifo_data_out;
  wire fifo_empty;
  wire fifo_read_req;

  // 1. Dual-Clock Asynchronous Memory Layer (The Clock Sync Bridge)
  uart_async_fifo #(
    .DATA_WIDTH(DATA_FRAME),
    .FIFO_DEPTH(16)
  ) TX_FIFO_BRIDGE (
    .i_wr_clk(i_clk),
    .i_wr_rst(i_rst),
    .i_wr_en(i_tx_start),
    .i_wr_data(i_tx_data),
    .i_rd_clk(i_clk), // Synchronized read pacing clock
    .i_rd_rst(i_rst),
    .i_rd_en(fifo_read_req),
    .o_rd_data(fifo_data_out),
    .o_empty(fifo_empty)
  );

  // 2. FSM Core Serialization Module
  uart_txuart_tx #(
    .DATA_FRAME        (DATA_FRAME),
    .BAUD_RATE         (BAUD_RATE),
    .OVERSAMPLING_MODE (OVERSAMPLING_MODE),
    .STOP_BIT          (STOP_BIT),
    .LSB               (LSB)
  ) uart_tx_wrapper (
    .i_clk             (i_clk),
    .i_rst             (i_rst),
    .i_tx_data         (fifo_data_out),
    .i_tx_start        (~fifo_empty), // Automatically trigger when data drops in
    .i_tick            (w_tick),
    .o_tx              (o_tx),
    .o_tx_done         (o_tx_done),
    .o_rd_ack          (fifo_read_req)
  );

  // 3. Timing Clock Div Ticker
  uart_txbaud_rate_generator_tx #(
    .BAUD_RATE         (BAUD_RATE),
    .OVERSAMPLING_MODE (OVERSAMPLING_MODE),
    .IN_CLK_HZ         (IN_CLK_HZ)
  ) baud_rate_gen_tx_wrapper (
    .i_clk             (i_clk),
    .i_rst             (i_rst),
    .o_tick            (w_tick)
  );

endmodule

// ===========================================================================
// SUB-MODULE 1: ASYNCHRONOUS POINTER-SYNC HARDWARE MEMORY BUFFER
// ===========================================================================
module uart_async_fifo #(
  parameter DATA_WIDTH = 8,
  parameter FIFO_DEPTH = 16
)(
  input                    i_wr_clk, i_wr_rst, i_wr_en,
  input   [DATA_WIDTH-1:0] i_wr_data,
  input                    i_rd_clk, i_rd_rst, i_rd_en,
  output  [DATA_WIDTH-1:0] o_rd_data,
  output                   o_empty
);

  reg [DATA_WIDTH-1:0] mem_array [FIFO_DEPTH-1:0];
  reg [3:0] wr_ptr = 0, rd_ptr = 0;
  
  // Cross clock domains safely using binary gray-code mapping
  wire [3:0] wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);
  reg  [3:0] rd_ptr_gray_sync = 0;
  
  always @(posedge i_wr_clk) begin
    if (i_wr_rst) wr_ptr <= 0;
    else if (i_wr_en) begin
      mem_array[wr_ptr] <= i_wr_data;
      wr_ptr <= wr_ptr + 1'b1;
    end
  end

  always @(posedge i_rd_clk) begin
    if (i_rd_rst) begin
      rd_ptr <= 0;
      rd_ptr_gray_sync <= 0;
    end else begin
      rd_ptr_gray_sync <= wr_ptr_gray; // Safe cross latch
      if (i_rd_en && !o_empty) begin
        rd_ptr <= rd_ptr + 1'b1;
      end
    end
  end

  assign o_rd_data = mem_array[rd_ptr];
  assign o_empty   = (rd_ptr ^ (rd_ptr >> 1)) == rd_ptr_gray_sync;

endmodule

// ===========================================================================
// SUB-MODULE 2: CORE FSM SERIALIZATION ENGINE
// ===========================================================================
module uart_txuart_tx #(
  parameter DATA_FRAME        = 8,           
  parameter BAUD_RATE         = 115_200,     
  parameter OVERSAMPLING_MODE = 16,          
  parameter STOP_BIT          = 1,           
  parameter LSB               = 1'b0         
) (
  input                       i_clk,        
  input                       i_rst,        
  input      [DATA_FRAME-1:0] i_tx_data,    
  input                       i_tx_start,   
  input                       i_tick,       
  output reg                  o_tx,         
  output reg                  o_tx_done,
  output reg                  o_rd_ack
);

  parameter [1:0] IDLE  = 2'b00;
  parameter [1:0] START = 2'b01;
  parameter [1:0] DATA  = 2'b10;
  parameter [1:0] STOP  = 2'b11;

  localparam [3:0] ADJ_OVERSAMPLE = OVERSAMPLING_MODE[3:0];

  reg [1:0] r_state = IDLE, r_next;
  reg [3:0] r_cnt = 4'd0;
  reg [2:0] r_index = 3'd0;
  reg [DATA_FRAME-1:0] r_tx_buffer = 0;

  always @(posedge i_clk) begin
    if (i_rst) r_state <= IDLE;
    else       r_state <= r_next;
  end

  always @* begin
    r_next = r_state;
    o_rd_ack = 1'b0;
    case (r_state)
      IDLE:  if (i_tx_start) begin r_next = START; o_rd_ack = 1'b1; end
      START: if (r_cnt == 4'd0 && i_tick) r_next = DATA;
      DATA:  if (r_cnt == 4'd0 && i_tick && r_index == 3'd7) r_next = STOP;
      STOP:  if (r_cnt == 4'd0 && i_tick) r_next = IDLE;
      default: r_next = IDLE;
    endcase
  end

  always @(posedge i_clk) begin
    if (i_rst) begin
      o_tx <= 1'b1;
      o_tx_done <= 1'b0;
      r_cnt <= 4'd0;
      r_index <= 3'd0;
    end else begin
      case (r_state)
        IDLE: begin
          o_tx <= 1'b1;
          o_tx_done <= 1'b0;
          r_cnt <= ADJ_OVERSAMPLE - 1'b1;
          r_index <= 3'd0;
          if (i_tx_start) r_tx_buffer <= i_tx_data;
        end
        START: begin
          o_tx <= 1'b0;
          if (i_tick) r_cnt <= r_cnt - 1'b1;
        end
        DATA: begin
          o_tx <= (LSB == 1'b1) ? r_tx_buffer[DATA_FRAME-1] : r_tx_buffer[0];
          if (i_tick) begin
            if (r_cnt == 4'd0) begin
              r_cnt <= ADJ_OVERSAMPLE - 1'b1;
              r_index <= r_index + 1'b1;
              r_tx_buffer <= (LSB == 1'b1) ? (r_tx_buffer << 1) : (r_tx_buffer >> 1);
            end else begin
              r_cnt <= r_cnt - 1'b1;
            end
          end
        end
        STOP: begin
          o_tx <= 1'b1;
          if (i_tick) begin
            if (r_cnt == 4'd0) begin
              o_tx_done <= 1'b1;
            end else begin
              r_cnt <= r_cnt - 1'b1;
            end
          end
        end
      endcase
    end
  end
endmodule

// ===========================================================================
// SUB-MODULE 3: CLOCK TICK DIVIDER GENERATOR
// ===========================================================================
module uart_txbaud_rate_generator_tx #(
  parameter IN_CLK_HZ         = 50_000_000,
  parameter BAUD_RATE         = 115_200,
  parameter OVERSAMPLING_MODE = 16
) (
  input      i_clk,
  input      i_rst,
  output reg o_tick
);
  localparam RAW_DIV_CNT_VAL = (IN_CLK_HZ / (BAUD_RATE * OVERSAMPLING_MODE)) - 1;
  localparam DIV_CNT_WIDTH   = $clog2(RAW_DIV_CNT_VAL);

  parameter [DIV_CNT_WIDTH-1:0] DIV_CNT_VAL = RAW_DIV_CNT_VAL[DIV_CNT_WIDTH-1:0];
  reg [DIV_CNT_WIDTH-1:0] r_count = 0;

  always @(posedge i_clk) begin
    if (i_rst) begin r_count <= 0; o_tick <= 1'b0; end
    else begin
      r_count <= r_count + 1'b1;
      o_tick  <= 1'b0;
      if (r_count == DIV_CNT_VAL) begin r_count <= 0; o_tick <= 1'b1; end
    end
  end
endmodule